# contrib/passwordcheck/Makefile

MODULE_big = passwordcheck
OBJS = passwordcheck.o $(WIN32RES)
PGFILEDESC = "passwordcheck - strengthen user password checks"

REGRESS = passwordcheck

# uncomment the following two lines to enable cracklib support
# PG_CPPFLAGS = -DUSE_CRACKLIB '-DCRACKLIB_DICTPATH="/usr/lib/cracklib_dict"'
# SHLIB_LINK = -lcrack

# YB note: USE_PGXS is by default 0 in contrib hence use Makefile.global
ifdef USE_PGXS
PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
else
subdir = contrib/passwordcheck
top_builddir = ../..
include $(top_builddir)/src/Makefile.global
include $(top_srcdir)/contrib/contrib-global.mk
endif
