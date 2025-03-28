--
-- ADVISORY LOCKS
--

BEGIN;

SELECT
	pg_advisory_xact_lock(1), pg_advisory_xact_lock_shared(2),
	pg_advisory_xact_lock(1, 1), pg_advisory_xact_lock_shared(2, 2);

SELECT pg_sleep(2);  -- YB: sleep 2 second to ensure advisory lock tablets are propagated(via the transaction heartbeat)
SELECT locktype, classid, objid, objsubid, mode, granted
	FROM pg_locks WHERE locktype = 'advisory'
	ORDER BY classid, objid, objsubid;


-- pg_advisory_unlock_all() shouldn't release xact locks
SELECT pg_advisory_unlock_all();

SELECT pg_sleep(2);  -- YB: sleep 2 second to ensure advisory lock tablets are propagated(via the transaction heartbeat)
SELECT count(*) FROM pg_locks WHERE locktype = 'advisory';


SELECT
	pg_advisory_unlock(1), pg_advisory_unlock_shared(2),
	pg_advisory_unlock(1, 1), pg_advisory_unlock_shared(2, 2);


-- automatically release xact locks at commit
COMMIT;

SELECT pg_sleep(2);  -- YB: sleep 2 second to ensure advisory lock tablets are propagated(via the transaction heartbeat)
SELECT count(*) FROM pg_locks WHERE locktype = 'advisory';


BEGIN;

-- holding both session and xact locks on the same objects, xact first
SELECT
	pg_advisory_xact_lock(1), pg_advisory_xact_lock_shared(2),
	pg_advisory_xact_lock(1, 1), pg_advisory_xact_lock_shared(2, 2);

SELECT pg_sleep(2);  -- YB: sleep 2 second to ensure advisory lock tablets are propagated(via the transaction heartbeat)
SELECT locktype, classid, objid, objsubid, mode, granted
	FROM pg_locks WHERE locktype = 'advisory'
	ORDER BY classid, objid, objsubid;

SELECT
	pg_advisory_lock(1), pg_advisory_lock_shared(2),
	pg_advisory_lock(1, 1), pg_advisory_lock_shared(2, 2);

ROLLBACK;

SELECT pg_sleep(2);  -- YB: sleep 2 second to ensure advisory lock tablets are propagated(via the transaction heartbeat)
SELECT locktype, classid, objid, objsubid, mode, granted
	FROM pg_locks WHERE locktype = 'advisory'
	ORDER BY classid, objid, objsubid;


SELECT
	pg_advisory_unlock(1), pg_advisory_unlock(1),
	pg_advisory_unlock_shared(2), pg_advisory_unlock_shared(2),
	pg_advisory_unlock(1, 1), pg_advisory_unlock(1, 1),
	pg_advisory_unlock_shared(2, 2), pg_advisory_unlock_shared(2, 2);

SELECT pg_sleep(2);  -- YB: sleep 2 second to ensure advisory lock tablets are propagated(via the transaction heartbeat)
SELECT count(*) FROM pg_locks WHERE locktype = 'advisory';


BEGIN;

-- holding both session and xact locks on the same objects, session first
SELECT
	pg_advisory_lock(1), pg_advisory_lock_shared(2),
	pg_advisory_lock(1, 1), pg_advisory_lock_shared(2, 2);

SELECT pg_sleep(2);  -- YB: sleep 2 second to ensure advisory lock tablets are propagated(via the transaction heartbeat)
SELECT locktype, classid, objid, objsubid, mode, granted
	FROM pg_locks WHERE locktype = 'advisory'
	ORDER BY classid, objid, objsubid;

SELECT
	pg_advisory_xact_lock(1), pg_advisory_xact_lock_shared(2),
	pg_advisory_xact_lock(1, 1), pg_advisory_xact_lock_shared(2, 2);

ROLLBACK;

SELECT pg_sleep(2);  -- YB: sleep 2 second to ensure advisory lock tablets are propagated(via the transaction heartbeat)
SELECT locktype, classid, objid, objsubid, mode, granted
	FROM pg_locks WHERE locktype = 'advisory'
	ORDER BY classid, objid, objsubid;


-- releasing all session locks
SELECT pg_advisory_unlock_all();

SELECT pg_sleep(2);  -- YB: sleep 2 second to ensure advisory lock tablets are propagated(via the transaction heartbeat)
SELECT count(*) FROM pg_locks WHERE locktype = 'advisory';


BEGIN;

-- grabbing txn locks multiple times

SELECT
	pg_advisory_xact_lock(1), pg_advisory_xact_lock(1),
	pg_advisory_xact_lock_shared(2), pg_advisory_xact_lock_shared(2),
	pg_advisory_xact_lock(1, 1), pg_advisory_xact_lock(1, 1),
	pg_advisory_xact_lock_shared(2, 2), pg_advisory_xact_lock_shared(2, 2);

SELECT pg_sleep(2);  -- YB: sleep 2 second to ensure advisory lock tablets are propagated(via the transaction heartbeat)
-- YB: TODO(GH#26179): ensure pg_locks shows only one advisory lock per key
SELECT locktype, classid, objid, objsubid, mode, granted
	FROM pg_locks WHERE locktype = 'advisory'
	ORDER BY classid, objid, objsubid;

COMMIT;

SELECT pg_sleep(2);  -- YB: sleep 2 second to ensure advisory lock tablets are propagated(via the transaction heartbeat)
SELECT count(*) FROM pg_locks WHERE locktype = 'advisory';

-- grabbing session locks multiple times

SELECT
	pg_advisory_lock(1), pg_advisory_lock(1),
	pg_advisory_lock_shared(2), pg_advisory_lock_shared(2),
	pg_advisory_lock(1, 1), pg_advisory_lock(1, 1),
	pg_advisory_lock_shared(2, 2), pg_advisory_lock_shared(2, 2);

SELECT pg_sleep(2);  -- YB: sleep 2 second to ensure advisory lock tablets are propagated(via the transaction heartbeat)
-- YB: TODO(GH#26179): ensure pg_locks shows only one advisory lock per key
SELECT locktype, classid, objid, objsubid, mode, granted
	FROM pg_locks WHERE locktype = 'advisory'
	ORDER BY classid, objid, objsubid;

SELECT
	pg_advisory_unlock(1), pg_advisory_unlock(1),
	pg_advisory_unlock_shared(2), pg_advisory_unlock_shared(2),
	pg_advisory_unlock(1, 1), pg_advisory_unlock(1, 1),
	pg_advisory_unlock_shared(2, 2), pg_advisory_unlock_shared(2, 2);

SELECT pg_sleep(2);  -- YB: sleep 2 second to ensure advisory lock tablets are propagated(via the transaction heartbeat)
SELECT count(*) FROM pg_locks WHERE locktype = 'advisory';

-- .. and releasing them all at once

SELECT
	pg_advisory_lock(1), pg_advisory_lock(1),
	pg_advisory_lock_shared(2), pg_advisory_lock_shared(2),
	pg_advisory_lock(1, 1), pg_advisory_lock(1, 1),
	pg_advisory_lock_shared(2, 2), pg_advisory_lock_shared(2, 2);

SELECT pg_sleep(2);  -- YB: sleep 2 second to ensure advisory lock tablets are propagated(via the transaction heartbeat)
-- YB: TODO(GH#26179): ensure pg_locks shows only one advisory lock per key
SELECT locktype, classid, objid, objsubid, mode, granted
	FROM pg_locks WHERE locktype = 'advisory'
	ORDER BY classid, objid, objsubid;

SELECT pg_advisory_unlock_all();

SELECT pg_sleep(2);  -- YB: sleep 2 second to ensure advisory lock tablets are propagated(via the transaction heartbeat)
SELECT count(*) FROM pg_locks WHERE locktype = 'advisory';
