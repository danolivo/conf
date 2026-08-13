MODULE_big = opcost
OBJS = opcost.o
EXTENSION = opcost
DATA = opcost--1.0.sql
PGFILEDESC = "opcost - measure operator function cost without the executor"

# Built against a specific install, e.g.
#   make USE_PGXS=1 PG_CONFIG=/opt/pgdev/1C_18_1/bin/pg_config install
PG_CONFIG ?= pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
