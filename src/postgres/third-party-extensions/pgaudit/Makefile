# contrib/pg_audit/Makefile

MODULE_big = pgaudit
OBJS = pgaudit.o $(WIN32RES)

EXTENSION = pgaudit
DATA = pgaudit--1.7.1.sql pgaudit--1.7--1.7.1.sql pgaudit--1.3.2--1.7.sql
PGFILEDESC = "pgAudit - An audit logging extension for PostgreSQL"
SHLIB_LINK += -L$(YB_BUILD_ROOT)/lib -lserver_process -lyb_pggate_webserver

REGRESS = pgaudit
REGRESS_OPTS = --temp-config=$(top_srcdir)/contrib/pgaudit/pgaudit.conf

ifdef USE_PGXS
PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
else
subdir = contrib/pgaudit
top_builddir = ../..
include $(top_builddir)/src/Makefile.global
include $(top_srcdir)/contrib/contrib-global.mk
endif

EXTRA_INSTALL += contrib/pg_stat_statements
