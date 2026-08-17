MODULE_big = agg_support
OBJS = agg_support.o
EXTENSION = agg_support
DATA = agg_support--1.0.sql
PGFILEDESC = "agg_support - demo aggregate planner support function"
REGRESS = agg_support

PG_CONFIG ?= pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
