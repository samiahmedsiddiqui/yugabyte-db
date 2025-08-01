\set VERBOSITY terse

-- Create pgaudit extension
CREATE EXTENSION IF NOT EXISTS pgaudit;

-- Grant all on public schema to public
GRANT ALL ON SCHEMA public TO public;

-- Make sure events don't get logged twice when session logging
SET pgaudit.log = 'all';
SET pgaudit.log_client = ON;
SET pgaudit.log_level = 'notice';

CREATE TABLE tmp (id int, data text);
CREATE TABLE tmp2 AS (SELECT * FROM tmp);

-- Reset log_client first to show that audits logs are not set to client
RESET pgaudit.log_client;

DROP TABLE tmp;
DROP TABLE tmp2;

RESET pgaudit.log;
RESET pgaudit.log_level;

--
-- Audit log fields are:
--     AUDIT_TYPE - SESSION or OBJECT
--     STATEMENT_ID - ID of the statement in the current backend
--     SUBSTATEMENT_ID - ID of the substatement in the current backend
--     CLASS - Class of statement being logged (e.g. ROLE, READ, WRITE)
--     COMMAND - e.g. SELECT, CREATE ROLE, UPDATE
--     OBJECT_TYPE - When available, type of object acted on (e.g. TABLE, VIEW)
--     OBJECT_NAME - When available, fully-qualified table of object
--     STATEMENT - The statement being logged
--     PARAMETER - If parameter logging is requested, they will follow the
--                 statement
--     ROWS - If rows logging is requested, they will follow the parameter

SELECT current_user \gset

--
-- Set pgaudit parameters for the current (super)user.
ALTER ROLE :current_user SET pgaudit.log = 'Role';
ALTER ROLE :current_user SET pgaudit.log_level = 'notice';
ALTER ROLE :current_user SET pgaudit.log_client = ON;

\connect - :current_user;

--
-- Create auditor role
CREATE ROLE regress_auditor;

--
-- Create first test user
CREATE USER regress_user1 password 'password';
ALTER ROLE regress_user1 SET pgaudit.log = 'ddl, ROLE';
ALTER ROLE regress_user1 SET pgaudit.log_level = 'notice';

ALTER ROLE regress_user1 PassWord 'password2' NOLOGIN;
ALTER USER regress_user1 encrypted /* random comment */PASSWORD
	/* random comment */
    'md565cb1da342495ea6bb0418a6e5718c38' LOGIN;
ALTER ROLE regress_user1 SET pgaudit.log_client = ON;

--
-- Create, select, drop (select will not be audited)
\connect - regress_user1

CREATE TABLE public.test
(
	id INT
);

SELECT *
  FROM test;

DROP TABLE test;

--
-- Create second test user
\connect - :current_user

CREATE ROLE regress_user2 LOGIN password 'password';
ALTER ROLE regress_user2 SET pgaudit.log = 'Read, writE';
ALTER ROLE regress_user2 SET pgaudit.log_catalog = OFF;
ALTER ROLE regress_user2 SET pgaudit.log_client = ON;
ALTER ROLE regress_user2 SET pgaudit.log_level = 'warning';
ALTER ROLE regress_user2 SET pgaudit.role = regress_auditor;
ALTER ROLE regress_user2 SET pgaudit.log_statement_once = ON;

--
-- Setup role-based tests
CREATE TABLE test2
(
	id INT
);

GRANT SELECT, INSERT, UPDATE, DELETE
   ON test2
   TO regress_user2, regress_user1;

GRANT SELECT, UPDATE
   ON TABLE public.test2
   TO regress_auditor;

CREATE TABLE test3
(
	id INT
);

GRANT SELECT, INSERT, UPDATE, DELETE
   ON test3
   TO regress_user2;

GRANT INSERT
   ON TABLE public.test3
   TO regress_auditor;

CREATE FUNCTION test2_insert() RETURNS TRIGGER AS $$
BEGIN
	UPDATE test2
	   SET id = id + 90
	 WHERE id = new.id;

	RETURN new;
END $$ LANGUAGE plpgsql security definer;
ALTER FUNCTION test2_insert() OWNER TO regress_user1;

CREATE TRIGGER test2_insert_trg
	AFTER INSERT ON test2
	FOR EACH ROW EXECUTE PROCEDURE test2_insert();

CREATE FUNCTION test2_change(change_id int) RETURNS void AS $$
BEGIN
	UPDATE test2
	   SET id = id + 1
	 WHERE id = change_id;
END $$ LANGUAGE plpgsql security definer;
ALTER FUNCTION test2_change(int) OWNER TO regress_user2;

CREATE VIEW vw_test3 AS
SELECT *
  FROM test3;

GRANT SELECT
   ON vw_test3
   TO regress_user2;

GRANT SELECT
   ON vw_test3
   TO regress_auditor;

\connect - regress_user2

--
-- Role-based tests
SELECT count(*)
  FROM
(
	SELECT relname
	  FROM pg_class
	  LIMIT 1
) SUBQUERY;

SELECT *
  FROM test3, test2;

--
-- Object logged because of:
-- select on vw_test3
-- select on test2
SELECT *
  FROM vw_test3, test2;

--
-- Object logged because of:
-- insert on test3
-- select on test2
WITH CTE AS
(
	SELECT id
	  FROM test2
)
INSERT INTO test3
SELECT id
  FROM cte;

--
-- Object logged because of:
-- insert on test3
WITH CTE AS
(
	INSERT INTO test3 VALUES (1)
				   RETURNING id
)
INSERT INTO test2
SELECT id
  FROM cte;

DO $$ BEGIN PERFORM test2_change(91); END $$;

--
-- Object logged because of:
-- insert on test3
-- update on test2
WITH CTE AS
(
	UPDATE test2
	   SET id = 45
	 WHERE id = 92
	RETURNING id
)
INSERT INTO test3
SELECT id
  FROM cte;

--
-- Object logged because of:
-- insert on test2
WITH CTE AS
(
	INSERT INTO test2 VALUES (37)
				   RETURNING id
)
UPDATE test3
   SET id = cte.id
  FROM cte
 WHERE test3.id <> cte.id;

--
-- Be sure that test has correct contents
SELECT *
  FROM test2
 ORDER BY ID;

--
-- Change permissions of user 2 so that only object logging will be done
\connect - :current_user
ALTER ROLE regress_user2 SET pgaudit.log = 'NONE';

\connect - regress_user2

--
-- Create test4 and add permissions
CREATE TABLE test4
(
	id int,
	name text
);

GRANT SELECT (name)
   ON TABLE public.test4
   TO regress_auditor;

GRANT UPDATE (id)
   ON TABLE public.test4
   TO regress_auditor;

GRANT insert (name)
   ON TABLE public.test4
   TO regress_auditor;

--
-- Not object logged
SELECT id
  FROM public.test4;

--
-- Object logged because of:
-- select (name) on test4
SELECT name
  FROM public.test4;

--
-- Not object logged
INSERT INTO public.test4 (id)
				  VALUES (1);

--
-- Object logged because of:
-- insert (name) on test4
INSERT INTO public.test4 (name)
				  VALUES ('test');

--
-- Not object logged
UPDATE public.test4
   SET name = 'foo';

--
-- Object logged because of:
-- update (id) on test4
UPDATE public.test4
   SET id = 1;

--
-- Object logged because of:
-- update (name) on test4
-- update (name) takes precedence over select (name) due to ordering
update public.test4 set name = 'foo' where name = 'bar';

--
-- Change permissions of user 1 so that session logging will be done
\connect - :current_user

--
-- Drop test tables
DROP TABLE test2;
DROP VIEW vw_test3;
DROP TABLE test3;
DROP TABLE test4;
DROP FUNCTION test2_insert();
DROP FUNCTION test2_change(int);

ALTER ROLE regress_user1 SET pgaudit.log = 'DDL, READ';
\connect - regress_user1

--
-- Create table is session logged
CREATE TABLE public.account
(
	id INT,
	name TEXT,
	password TEXT,
	description TEXT
);

--
-- Select is session logged
SELECT *
  FROM account;

--
-- Insert is not logged
INSERT INTO account (id, name, password, description)
			 VALUES (1, 'regress_user1', 'HASH1', 'blah, blah');

--
-- Change permissions of user 1 so that only object logging will be done
\connect - :current_user
ALTER ROLE regress_user1 SET pgaudit.log = 'none';
ALTER ROLE regress_user1 SET pgaudit.role = 'regress_auditor';
\connect - regress_user1

--
-- ROLE class not set, so regress_auditor grants not logged
GRANT SELECT (password),
	  UPDATE (name, password)
   ON TABLE public.account
   TO regress_auditor;

--
-- Not object logged
SELECT id,
	   name
  FROM account;

--
-- Object logged because of:
-- select (password) on account
SELECT password
  FROM account;

--
-- Not object logged
UPDATE account
   SET description = 'yada, yada';

--
-- Object logged because of:
-- update (password) on account
UPDATE account
   SET password = 'HASH2';

--
-- Change permissions of user 1 so that session relation logging will be done
\connect - :current_user
ALTER ROLE regress_user1 SET pgaudit.log_relation = on;
ALTER ROLE regress_user1 SET pgaudit.log = 'read, WRITE';
\connect - regress_user1

--
-- Not logged
CREATE TABLE ACCOUNT_ROLE_MAP
(
	account_id INT,
	role_id INT
);

--
-- ROLE class not set, so regress_auditor grants not logged
GRANT SELECT
   ON TABLE public.account_role_map
   TO regress_auditor;

--
-- Object logged because of:
-- select (password) on account
-- select on account_role_map
-- Session logged on all tables because log = read and log_relation = on
SELECT account.password,
	   account_role_map.role_id
  FROM account
	   INNER JOIN account_role_map
			on account.id = account_role_map.account_id;

--
-- Object logged because of:
-- select (password) on account
-- Session logged on all tables because log = read and log_relation = on
SELECT password
  FROM account;

--
-- Not object logged
-- Session logged on all tables because log = read and log_relation = on
UPDATE account
   SET description = 'yada, yada';

--
-- Object logged because of:
--     select (password) on account (in the where clause)
-- Session logged on all tables because log = read and log_relation = on
SELECT *
  FROM account
 WHERE password = 'HASH2'
   FOR UPDATE;

--
-- Object logged because of:
-- select (password) on account (in the where clause)
-- Session logged on all tables because log = read and log_relation = on
UPDATE account
   SET description = 'yada, yada'
 where password = 'HASH2';

--
-- Object logged because of:
-- update (password) on account
-- Session logged on all tables because log = read and log_relation = on
UPDATE account
   SET password = 'HASH2';

--
-- Change configuration of user 1 so that full statements are not logged
\connect - :current_user
ALTER ROLE regress_user1 RESET pgaudit.log_relation;
ALTER ROLE regress_user1 RESET pgaudit.log;
ALTER ROLE regress_user1 SET pgaudit.log_statement = OFF;
\connect - regress_user1

--
-- Logged but without full statement
SELECT * FROM account;

--
-- Change back to superuser to do exhaustive tests
\connect - :current_user
SET pgaudit.log = 'ALL';
SET pgaudit.log_level = 'notice';
SET pgaudit.log_client = ON;
SET pgaudit.log_relation = ON;
SET pgaudit.log_parameter = ON;

--
-- Simple DO block
DO $$
BEGIN
	raise notice 'test';
END $$;

--
-- Create test schema
CREATE SCHEMA test;

--
-- Copy account to stdout
COPY account TO stdout;

--
-- Create a table from a query
CREATE TABLE test.account_copy AS
SELECT *
  FROM account;

--
-- Copy from stdin to account copy
COPY test.account_copy from stdin;
1	regress_user1	HASH2	yada, yada
\.

--
-- Test prepared statement
PREPARE pgclassstmt (oid) AS
SELECT *
  FROM account
 WHERE id = $1;

EXECUTE pgclassstmt (1);
DEALLOCATE pgclassstmt;

--
-- Test cursor
BEGIN;

DECLARE ctest SCROLL CURSOR FOR
SELECT count(*)
  FROM
(
	SELECT relname
	  FROM pg_class
	 LIMIT 1
 ) subquery;

FETCH NEXT FROM ctest;
CLOSE ctest;
COMMIT;

--
-- Turn off log_catalog and pg_class will not be logged
SET pgaudit.log_catalog = OFF;

SELECT count(*)
  FROM
(
	SELECT relname
	  FROM pg_class
	 LIMIT 1
 ) subquery;

--
-- Test prepared insert
CREATE TABLE test.test_insert
(
	id INT
);

PREPARE pgclassstmt (oid) AS
INSERT INTO test.test_insert (id)
					  VALUES ($1);
EXECUTE pgclassstmt (1);

--
-- Check that primary key creation is logged
CREATE TABLE public.test
(
	id INT,
	name TEXT,
	description TEXT,
	CONSTRAINT test_pkey PRIMARY KEY (id)
);

--
-- Check that analyze is logged
ANALYZE test;

--
-- Grants to public should not cause object logging (session logging will
-- still happen)
GRANT SELECT
  ON TABLE public.test
  TO PUBLIC;

SELECT *
  FROM test;

-- Check that statements without columns log
SELECT
  FROM test;

SELECT 1,
	   substring('Thomas' from 2 for 3);

DO $$
DECLARE
	test INT;
BEGIN
	SELECT 1
	  INTO test;
END $$;

explain select 1;

--
-- Test that looks inside of do blocks log
INSERT INTO TEST (id)
		  VALUES (1);
INSERT INTO TEST (id)
		  VALUES (2);
INSERT INTO TEST (id)
		  VALUES (3);

DO $$
DECLARE
	result RECORD;
BEGIN
	FOR result IN
		SELECT id
		  FROM test
	LOOP
		INSERT INTO test (id)
			 VALUES (result.id + 100);
	END LOOP;
END $$;

--
-- Test obfuscated dynamic sql for clean logging
DO $$
DECLARE
	table_name TEXT = 'do_table';
BEGIN
	EXECUTE 'CREATE TABLE ' || table_name || ' ("weird name" INT)';
	EXECUTE 'DROP table ' || table_name;
END $$;

--
-- Generate an error and make sure the stack gets cleared
DO $$
BEGIN
	CREATE TABLE bogus.test_block
	(
		id INT
	);
END $$;

--
-- Test alter table statements
ALTER TABLE public.test
	DROP COLUMN description ;

ALTER TABLE public.test
	RENAME TO test2;

ALTER TABLE public.test2
	SET SCHEMA test;

ALTER TABLE test.test2
	ADD COLUMN description TEXT;

ALTER TABLE test.test2
	DROP COLUMN description;

DROP TABLE test.test2;

--
-- Test multiple statements with one semi-colon
CREATE SCHEMA foo
	CREATE TABLE foo.bar (id int)
	CREATE TABLE foo.baz (id int);
SELECT 'yb'; -- YB: bump audit number to stay same with upstream

--
-- Test aggregate
CREATE FUNCTION public.int_add
(
	a INT,
	b INT
)
	RETURNS INT LANGUAGE plpgsql AS $$
BEGIN
	return a + b;
END $$;

SELECT int_add(1, 1);

CREATE AGGREGATE public.sum_test(INT) (SFUNC=public.int_add, STYPE=INT, INITCOND='0');
ALTER AGGREGATE public.sum_test(integer) RENAME TO sum_test2;

--
-- Test conversion
CREATE CONVERSION public.conversion_test FOR 'latin1' TO 'utf8' FROM pg_catalog.iso8859_1_to_utf8;
SELECT 'yb'; -- YB: bump audit number to stay same with upstream
ALTER CONVERSION public.conversion_test RENAME TO conversion_test2;
SELECT 'yb'; -- YB: bump audit number to stay same with upstream

--
-- Test create/alter/drop database
CREATE DATABASE contrib_regression_pgaudit;
ALTER DATABASE contrib_regression_pgaudit RENAME TO contrib_regression_pgaudit2;
DROP DATABASE contrib_regression_pgaudit2;

-- Test role as a substmt
SET pgaudit.log = 'ROLE';

CREATE TABLE t ();
CREATE ROLE regress_alice;

CREATE SCHEMA foo2
	GRANT SELECT
	   ON public.t
	   TO regress_alice;
ALTER ROLE regress_alice CONNECTION LIMIT -1; -- YB: bump audit number to stay same with upstream

drop table public.t;
drop role regress_alice;

--
-- Test for non-empty stack error
CREATE OR REPLACE FUNCTION get_test_id(_ret REFCURSOR) RETURNS REFCURSOR
LANGUAGE plpgsql IMMUTABLE AS $$
BEGIN
    OPEN _ret FOR SELECT 200;
    RETURN _ret;
END $$;

BEGIN;
    SELECT get_test_id('_ret');
    SELECT get_test_id('_ret2');
    FETCH ALL FROM _ret;
    FETCH ALL FROM _ret2;
    CLOSE _ret;
    CLOSE _ret2;
END;

--
-- Test that frees a memory context earlier than expected
SET pgaudit.log = 'ALL';

CREATE TABLE hoge
(
	id int
);

CREATE FUNCTION test()
	RETURNS INT AS $$
DECLARE
	cur1 cursor for select * from hoge;
	tmp int;
BEGIN
	OPEN cur1;
	FETCH cur1 into tmp;
	RETURN tmp;
END $$
LANGUAGE plpgsql ;

SELECT test();

--
-- Delete all rows then delete 1 row
SET pgaudit.log = 'write';
SET pgaudit.role = 'regress_auditor';

create table bar
(
	col int
);

grant delete
   on bar
   to regress_auditor;

insert into bar (col)
		 values (1);
delete from bar;

insert into bar (col)
		 values (1);
delete from bar
 where col = 1;

drop table bar;

--
-- Grant roles to each other
SET pgaudit.log = 'role';
GRANT regress_user1 TO regress_user2;
REVOKE regress_user1 FROM regress_user2;

--
-- Test that FK references do not log but triggers still do
SET pgaudit.log = 'READ,WRITE';
SET pgaudit.role TO 'regress_auditor';

CREATE TABLE aaa
(
	ID int primary key
);

CREATE TABLE bbb
(
	id int
		references aaa(id)
);

CREATE FUNCTION bbb_insert() RETURNS TRIGGER AS $$
BEGIN
	UPDATE bbb set id = new.id + 1;

	RETURN new;
END $$ LANGUAGE plpgsql;

CREATE TRIGGER bbb_insert_trg
	AFTER INSERT ON bbb
	FOR EACH ROW EXECUTE PROCEDURE bbb_insert();

GRANT SELECT, UPDATE
   ON aaa
   TO regress_auditor;

GRANT UPDATE
   ON bbb
   TO regress_auditor;

INSERT INTO aaa VALUES (generate_series(1,100));

SET pgaudit.log_parameter TO OFF;
INSERT INTO bbb VALUES (1); -- YB: output differs (unknown reason)
SET pgaudit.log_parameter TO ON;

DROP TABLE bbb;
DROP TABLE aaa;

-- Test create table as after extension as been dropped
DROP EXTENSION pgaudit;

CREATE TABLE tmp (id int, data text);
CREATE TABLE tmp2 AS (SELECT * FROM tmp);

DROP TABLE tmp;
DROP TABLE tmp2;

--
-- Test MISC
SET pgaudit.log = 'MISC';
SET pgaudit.log_level = 'notice';
SET pgaudit.log_client = ON;
SET pgaudit.log_relation = ON;
SET pgaudit.log_parameter = ON;

CREATE ROLE regress_alice;

SET ROLE regress_alice;
CREATE TABLE t (a int, b text);
SET search_path TO test, public;

INSERT INTO t VALUES (1, 'misc');

VACUUM t;
RESET ROLE;

--
-- Test MISC_SET
SET pgaudit.log = 'MISC_SET';

SET ROLE regress_alice;
SET search_path TO public;

INSERT INTO t VALUES (2, 'misc_set');

VACUUM t;
RESET ROLE;

--
-- Test ALL, -MISC, MISC_SET
SET pgaudit.log = 'ALL, -MISC, MISC_SET';

SET search_path TO public;

INSERT INTO t VALUES (3, 'all, -misc, misc_set');

VACUUM t;

RESET ROLE;
DROP TABLE public.t;
DROP ROLE regress_alice;

--
-- Test PARTITIONED table
CREATE TABLE h(x int ,y int) PARTITION BY HASH(x);
CREATE TABLE h_0 partition OF h FOR VALUES WITH ( MODULUS 2, REMAINDER 0);
CREATE TABLE h_1 partition OF h FOR VALUES WITH ( MODULUS 2, REMAINDER 1);
INSERT INTO h VALUES(1,1);
SELECT * FROM h;
SELECT * FROM h_0;
CREATE INDEX h_idx ON h (x);
DROP INDEX h_idx;
DROP TABLE h;

--
-- Test rows retrived or affected by statements
\connect - :current_user

SET pgaudit.log = 'all';
SET pgaudit.log_client = on;
SET pgaudit.log_relation = on;
SET pgaudit.log_statement_once = off;
SET pgaudit.log_parameter = on;
SET pgaudit.log_rows = on;

--
-- Test DDL
CREATE TABLE test2
(
	id int,
	name text
);

CREATE TABLE test3
(
	id int,
	name text
);

CREATE FUNCTION test2_insert() RETURNS TRIGGER AS $$
BEGIN
	UPDATE test2
	   SET id = id + 90
	 WHERE id = new.id;

	RETURN new;
END $$ LANGUAGE plpgsql security definer;

CREATE TRIGGER test2_insert_trg
	AFTER INSERT ON test2
	FOR EACH ROW EXECUTE PROCEDURE test2_insert();

CREATE FUNCTION test2_change(change_id int) RETURNS void AS $$
BEGIN
	UPDATE test2
	   SET id = id + 1
	 WHERE id = change_id;
END $$ LANGUAGE plpgsql security definer;

CREATE VIEW vw_test3 AS
SELECT *
  FROM test3;

--
-- Test DML
INSERT INTO test2 (id, name)
		  VALUES (1, 'a');
INSERT INTO test2 (id, name)
		  VALUES (2, 'b');
INSERT INTO test2 (id, name)
		  VALUES (3, 'c');

INSERT INTO test3 (id, name)
		  VALUES (1, 'a');
INSERT INTO test3 (id, name)
		  VALUES (2, 'b');
INSERT INTO test3 (id, name)
		  VALUES (3, 'c');

SELECT *
  FROM test3, test2 ORDER BY test3.id, test2.id; -- YB: add ordering

SELECT *
  FROM vw_test3, test2 ORDER BY vw_test3.id, test2.id; -- YB: add ordering

SELECT *
  FROM test2
 ORDER BY ID;

UPDATE test2
   SET name = 'd';

UPDATE test3
   SET name = 'd'
 WHERE id > 0;

SELECT 1
  FROM
(
	SELECT relname
	  FROM pg_class
	  LIMIT 3
) SUBQUERY;

WITH CTE AS
(
	SELECT id
	  FROM test2
)
INSERT INTO test3
SELECT id
  FROM cte;

WITH CTE AS
(
	INSERT INTO test3 VALUES (1)
				   RETURNING id
)
INSERT INTO test2
SELECT id
  FROM cte;

DO $$ BEGIN PERFORM test2_change(91); END $$;

WITH CTE AS
(
	UPDATE test2
	   SET id = 45
	 WHERE id = 92
	RETURNING id
)
INSERT INTO test3
SELECT id
  FROM cte;

WITH CTE AS
(
	INSERT INTO test2 VALUES (37)
				   RETURNING id
)
UPDATE test3
   SET id = cte.id
  FROM cte
 WHERE test3.id <> cte.id;

DELETE
  FROM test2;

DELETE
  FROM test3
 WHERE id > 0;

--
-- Drop test tables
DROP TABLE test2;
DROP VIEW vw_test3;
DROP TABLE test3;
DROP FUNCTION test2_insert();
DROP FUNCTION test2_change(int);

--
-- Only object logging will be done
SET pgaudit.log = 'none';
SET pgaudit.role = 'regress_auditor';

--
-- Select is session logged
SELECT *
  FROM account;

--
-- Insert is not logged
INSERT INTO account (id, name, password, description)
			 VALUES (1, 'regress_user2', 'HASH3', 'blah, blah2');
INSERT INTO account (id, name, password, description)
			 VALUES (1, 'user3', 'HASH4', 'blah, blah3');

--
-- Not object logged
SELECT id,
	   name
  FROM account ORDER BY name; -- YB: add ordering

--
-- Object logged because of:
-- select (password) on account
SELECT password
  FROM account ORDER BY password; -- YB: add ordering

--
-- Not object logged
UPDATE account
   SET description = 'yada, yada1';

--
-- Object logged because of:
-- update (password) on account
UPDATE account
   SET password = 'HASH4';

--
-- Session relation logging will be done
SET pgaudit.log_relation = on;
SET pgaudit.log = 'read, write';

--
-- Object logged because of:
-- select (password) on account
-- select on account_role_map
-- Session logged on all tables because log = read and log_relation = on
SELECT account.password,
	   account_role_map.role_id
  FROM account
	   INNER JOIN account_role_map
			on account.id = account_role_map.account_id;

--
-- Object logged because of:
-- select (password) on account
-- Session logged on all tables because log = read and log_relation = on
SELECT password
  FROM account;

--
-- Not object logged
-- Session logged on all tables because log = read and log_relation = on
UPDATE account
   SET description = 'yada, yada2';

--
-- Object logged because of:
-- select (password) on account (in the where clause)
-- Session logged on all tables because log = read and log_relation = on
UPDATE account
   SET description = 'yada, yada3'
 where password = 'HASH4';

--
-- Object logged because of:
-- update (password) on account
-- Session logged on all tables because log = read and log_relation = on
UPDATE account
   SET password = 'HASH4';

--
-- Exhaustive tests
SET pgaudit.log = 'all';
SET pgaudit.log_client = on;
SET pgaudit.log_relation = on;
SET pgaudit.log_parameter = on;
SET pgaudit.log_rows = on;

--
-- Simple DO block
DO $$
BEGIN
	raise notice 'test';
END $$;

--
-- Copy account to stdout
/* YB: inconsistent output ordering
COPY account TO stdout;
*/ -- YB
SELECT * FROM account ORDER BY name; -- YB: workaround for above and to bump audit number

--
-- Drop a table from a query
DROP TABLE test.account_copy;

--
-- Create a table from a query
CREATE TABLE test.account_copy AS
SELECT *
  FROM account;

--
-- Copy from stdin to account copy
COPY test.account_copy from stdin;
1	regress_user1	HASH4	yada, yada4
\.

--
-- Test prepared statement
PREPARE pgclassstmt1 (oid) AS
SELECT 1
  FROM account
 WHERE id = $1;

PREPARE pgclassstmt2 (oid) AS
SELECT 2
  FROM account
 WHERE id = $1;

EXECUTE pgclassstmt2 (1);
EXECUTE pgclassstmt1 (1);

DEALLOCATE pgclassstmt2;
DEALLOCATE pgclassstmt1;

--
-- Test cursor
BEGIN;

DECLARE ctest1 SCROLL CURSOR FOR
SELECT 1
  FROM
(
	SELECT relname
	  FROM pg_class
	 LIMIT 3
 ) subquery;

DECLARE ctest2 SCROLL CURSOR FOR
SELECT 2
  FROM
(
	SELECT relname
	  FROM pg_class
	 LIMIT 3
 ) subquery;

FETCH NEXT FROM ctest1;
FETCH NEXT FROM ctest2;
FETCH NEXT FROM ctest1;
FETCH NEXT FROM ctest2;
FETCH NEXT FROM ctest1;
FETCH NEXT FROM ctest2;

CLOSE ctest2;
CLOSE ctest1;
COMMIT;

--
-- Turn off log_catalog and pg_class will not be logged
SET pgaudit.log_catalog = off;

SELECT count(*)
  FROM
(
	SELECT relname
	  FROM pg_class
	 LIMIT 1
 ) subquery;

--
-- Test prepared insert
DROP TABLE test.test_insert;

--
-- Test prepared insert
CREATE TABLE test.test_insert
(
	id INT
);

PREPARE pgclassstmt (oid) AS
INSERT INTO test.test_insert (id)
					  VALUES ($1);
EXECUTE pgclassstmt (1);

--
-- Check that primary key creation is logged
CREATE TABLE public.test
(
	id INT,
	name TEXT,
	description TEXT,
	CONSTRAINT test_pkey PRIMARY KEY (id)
);

--
-- Check that analyze is logged
ANALYZE test;

--
-- Grants to public should not cause object logging (session logging will
-- still happen)
GRANT SELECT
  ON TABLE public.test
  TO PUBLIC;

SELECT *
  FROM test;

-- Check that statements without columns log
SELECT
  FROM test;

SELECT 1,
	   substring('Thomas' from 2 for 3);

DO $$
DECLARE
	test INT;
BEGIN
	SELECT 1
	  INTO test;
END $$;

explain select 1;

--
-- Test that looks inside of do blocks log
INSERT INTO TEST (id)
		  VALUES (1);
INSERT INTO TEST (id)
		  VALUES (2);
INSERT INTO TEST (id)
		  VALUES (3);

DO $$
DECLARE
	result RECORD;
BEGIN
	FOR result IN
		SELECT id
		  FROM test
	LOOP
		INSERT INTO test (id)
			 VALUES (result.id + 100);
	END LOOP;
END $$;

--
-- Test obfuscated dynamic sql for clean logging
DO $$
DECLARE
	table_name TEXT = 'do_table';
BEGIN
	EXECUTE 'CREATE TABLE ' || table_name || ' ("weird name" INT)';
	EXECUTE 'DROP table ' || table_name;
END $$;

--
-- Generate an error and make sure the stack gets cleared
DO $$
BEGIN
	CREATE TABLE bogus.test_block
	(
		id INT
	);
END $$;

--
-- Test alter table statements
ALTER TABLE public.test
	DROP COLUMN description ;

ALTER TABLE public.test
	RENAME TO test2;

ALTER TABLE public.test2
	SET SCHEMA test;

ALTER TABLE test.test2
	ADD COLUMN description TEXT;

ALTER TABLE test.test2
	DROP COLUMN description;

DROP TABLE test.test2;

--
-- Test multiple statements with one semi-colon
CREATE SCHEMA foo1
	CREATE TABLE foo1.bar1 (id int)
	CREATE TABLE foo1.baz1 (id int);
SELECT 'yb'; -- YB: bump audit number to stay same with upstream.

DROP TABLE foo1.bar1;
SELECT 'yb'; -- YB: bump audit number to stay same with upstream
DROP TABLE foo1.baz1;
SELECT 'yb'; -- YB: bump audit number to stay same with upstream
DROP SCHEMA foo1;
SELECT 'yb'; -- YB: bump audit number to stay same with upstream

--
-- Test aggregate
CREATE FUNCTION public.int_add1
(
	a INT,
	b INT
)
	RETURNS INT LANGUAGE plpgsql AS $$
BEGIN
	return a + b;
END $$;

SELECT int_add1(1, 1);

CREATE AGGREGATE public.sum_test(INT) (SFUNC=public.int_add1, STYPE=INT, INITCOND='0');
ALTER AGGREGATE public.sum_test(integer) RENAME TO sum_test3;

--
-- Test conversion
CREATE CONVERSION public.conversion_test FOR 'latin1' TO 'utf8' FROM pg_catalog.iso8859_1_to_utf8;
SELECT 'yb'; -- YB: bump audit number to stay same with upstream
ALTER CONVERSION public.conversion_test RENAME TO conversion_test3;
SELECT 'yb'; -- YB: bump audit number to stay same with upstream

--
-- Test create/alter/drop database
CREATE DATABASE contrib_regression_pgaudit;
ALTER DATABASE contrib_regression_pgaudit RENAME TO contrib_regression_pgaudit2;
DROP DATABASE contrib_regression_pgaudit2;

-- Test role as a substmt
SET pgaudit.log = 'role';

CREATE TABLE t ();
CREATE ROLE regress_alice;

CREATE SCHEMA foo3
	GRANT SELECT
	   ON public.t
	   TO regress_alice;

drop table public.t;
drop role regress_alice;

--
-- Test for non-empty stack error
CREATE OR REPLACE FUNCTION get_test_id(_ret REFCURSOR) RETURNS REFCURSOR
LANGUAGE plpgsql IMMUTABLE AS $$
BEGIN
    OPEN _ret FOR SELECT 200;
    RETURN _ret;
END $$;

BEGIN;
    SELECT get_test_id('_ret');
    SELECT get_test_id('_ret2');
    FETCH ALL FROM _ret;
    FETCH ALL FROM _ret2;
    CLOSE _ret;
    CLOSE _ret2;
END;

--
-- Test that frees a memory context earlier than expected
SET pgaudit.log = 'all';

CREATE FUNCTION test1()
	RETURNS INT AS $$
DECLARE
	cur1 cursor for select * from hoge;
	tmp int;
BEGIN
	OPEN cur1;
	FETCH cur1 into tmp;
	RETURN tmp;
END $$
LANGUAGE plpgsql ;

SELECT test1();

--
-- Delete all rows then delete 1 row
SET pgaudit.log = 'write';
SET pgaudit.role = 'regress_auditor';

create table bar
(
	col int
);

grant delete
   on bar
   to regress_auditor;

insert into bar (col)
		 values (1);
delete from bar;

insert into bar (col)
		 values (1);
delete from bar
 where col = 1;

drop table bar;

--
-- Test that FK references do not log but triggers still do
SET pgaudit.log = 'read, write';
SET pgaudit.role TO 'regress_auditor';

CREATE TABLE aaa
(
	ID int primary key
);

CREATE TABLE bbb
(
	id int
		references aaa(id)
);

CREATE FUNCTION bbb_insert1() RETURNS TRIGGER AS $$
BEGIN
	UPDATE bbb set id = new.id + 1;

	RETURN new;
END $$ LANGUAGE plpgsql;

CREATE TRIGGER bbb_insert_trg1
	AFTER INSERT ON bbb
	FOR EACH ROW EXECUTE PROCEDURE bbb_insert1();

GRANT SELECT, UPDATE
   ON aaa
   TO regress_auditor;

GRANT UPDATE
   ON bbb
   TO regress_auditor;

INSERT INTO aaa VALUES (generate_series(1,100));

SET pgaudit.log_parameter TO OFF;
INSERT INTO bbb VALUES (1); -- YB: output differs (unknown reason)
SET pgaudit.log_parameter TO ON;

DROP TABLE bbb;
DROP TABLE aaa;

--
-- Test MISC
SET pgaudit.log = 'misc';
SET pgaudit.log_client = on;
SET pgaudit.log_relation = on;
SET pgaudit.log_parameter = on;

CREATE ROLE regress_alice;

SET ROLE regress_alice;
CREATE TABLE t (a int, b text);
SET search_path TO test, public;

INSERT INTO t VALUES (1, 'misc');

VACUUM t;
RESET ROLE;

--
-- Test MISC_SET
SET pgaudit.log = 'MISC_SET';

SET ROLE regress_alice;
SET search_path TO public;

INSERT INTO t VALUES (2, 'misc_set');

VACUUM t;
RESET ROLE;

--
-- Test ALL, -MISC, MISC_SET
SET pgaudit.log = 'ALL, -MISC, MISC_SET';
SET search_path TO public;

INSERT INTO t VALUES (3, 'all, -misc, misc_set');

VACUUM t;

RESET ROLE;
DROP TABLE public.t;
DROP ROLE regress_alice;

--
-- Test PARTITIONED table
CREATE TABLE h(x int ,y int) PARTITION BY HASH(x);
CREATE TABLE h_0 partition OF h FOR VALUES WITH ( MODULUS 2, REMAINDER 0);
CREATE TABLE h_1 partition OF h FOR VALUES WITH ( MODULUS 2, REMAINDER 1);
INSERT INTO h VALUES(1,1);
SELECT * FROM h;
SELECT * FROM h_0;
CREATE INDEX h_idx ON h (x);
DROP INDEX h_idx;
DROP TABLE h;

--
-- Change configuration of user 1 so that full statements are not logged
\connect - :current_user
ALTER ROLE regress_user1 RESET pgaudit.log_relation;
ALTER ROLE regress_user1 RESET pgaudit.log;
ALTER ROLE regress_user1 SET pgaudit.log_statement = OFF;
ALTER ROLE regress_user1 SET pgaudit.log_rows = on;
\connect - regress_user1

--
-- Logged but without full statement
SELECT * FROM account ORDER BY name; -- YB: add ordering

--
-- Change back to superuser to do exhaustive tests
\connect - :current_user

--
-- Test that pgaudit event triggers are immune to search-path-based attacks

-- Attempt to capture unqualified references to standard functions
CREATE FUNCTION upper(text) RETURNS text
LANGUAGE SQL AS 'SELECT (1/0)::text';

CREATE FUNCTION lower(text) RETURNS text
LANGUAGE SQL AS 'SELECT (1/0)::text';

CREATE FUNCTION my_ne(text, text) RETURNS bool
LANGUAGE SQL AS 'SELECT (1/0)::bool';

CREATE OPERATOR <> (FUNCTION = my_ne, LEFTARG = text, RIGHTARG = text);

CREATE EXTENSION IF NOT EXISTS pgaudit;
SET pgaudit.log = 'DDL';
-- Put public schema before pg_catalog to capture unqualified references
SET search_path = public, pg_catalog;

-- If there was a vulnerability, these would fail with division by zero error
CREATE TABLE wombat ();
DROP TABLE wombat;

SET pgaudit.log = 'NONE';
DROP EXTENSION pgaudit;

DROP OPERATOR <> (text, text);
DROP FUNCTION my_ne(text, text);
DROP FUNCTION lower(text);
DROP FUNCTION upper(text);

-- Create/drop extension. Note that the log level here must be warning because the create extension code will reset any higher log
-- levels like notice
SET pgaudit.log = 'all,-misc_set';
SET pgaudit.log_level = 'warning';

CREATE EXTENSION pg_stat_statements; -- YB: already installed by default
ALTER EXTENSION pg_stat_statements UPDATE TO '1.10-yb-1.0'; -- YB: change to latest version number
DROP EXTENSION pg_stat_statements;

SET pgaudit.log_level = 'notice';

-- Check that partition scans are skipped for auditing and do no result in an empty stack
SET pgaudit.log = 'all';

CREATE TABLE part_test (c1 int, c2 int) PARTITION BY RANGE (c1);
CREATE TABLE part_test_1_to_10 PARTITION OF part_test FOR VALUES FROM (1) TO (10);
INSERT INTO part_test VALUES (generate_series(1,9));

CREATE OR REPLACE FUNCTION get_test_id(_ret REFCURSOR) RETURNS REFCURSOR
LANGUAGE plpgsql IMMUTABLE AS $$
BEGIN
    OPEN _ret FOR SELECT * FROM part_test;
    RETURN _ret;
END $$;

BEGIN;
SELECT get_test_id('_ret');
FETCH ALL FROM _ret;
COMMIT;

DROP TABLE part_test;

-- Cleanup
-- Set client_min_messages up to warning to avoid noise
SET client_min_messages = 'warning';

ALTER ROLE :current_user RESET pgaudit.log;
ALTER ROLE :current_user RESET pgaudit.log_catalog;
ALTER ROLE :current_user RESET pgaudit.log_client;
ALTER ROLE :current_user RESET pgaudit.log_level;
ALTER ROLE :current_user RESET pgaudit.log_parameter;
ALTER ROLE :current_user RESET pgaudit.log_relation;
ALTER ROLE :current_user RESET pgaudit.log_statement;
ALTER ROLE :current_user RESET pgaudit.log_statement_once;
ALTER ROLE :current_user RESET pgaudit.role;

RESET pgaudit.log;
RESET pgaudit.log_catalog;
RESET pgaudit.log_level;
RESET pgaudit.log_parameter;
RESET pgaudit.log_relation;
RESET pgaudit.log_statement;
RESET pgaudit.log_statement_once;
RESET pgaudit.role;

DROP TABLE test.account_copy;
DROP TABLE test.test_insert;
DROP SCHEMA test;
DROP TABLE foo.bar; -- YB: fails due to prior CREATE failure
DROP TABLE foo.baz; -- YB: fails due to prior CREATE failure
DROP SCHEMA foo; -- YB: fails due to prior CREATE failure
DROP TABLE hoge;
DROP TABLE account;
DROP TABLE account_role_map;
DROP USER regress_user2;
DROP USER regress_user1;
DROP ROLE regress_auditor;

RESET client_min_messages;
