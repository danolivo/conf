MODULE_big = dec64
OBJS = dec64.o
EXTENSION = dec64
DATA = dec64--1.0.sql
REGRESS = dec64
PGFILEDESC = "dec64 - exact fixed-point decimal in a machine word"

PG_CONFIG ?= $(HOME)/pgdev-upstream/tmp_install/bin/pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
