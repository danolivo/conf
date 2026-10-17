DROP TABLE IF EXISTS narrow;
CREATE TABLE narrow (
  id bigint NOT NULL,
  n1 numeric(12,2),
  n2 numeric(20,8),
  n3 numeric,
  q int4,
  ts timestamptz
);
DROP TABLE IF EXISTS wide;
CREATE TABLE wide (
  id bigint NOT NULL,
  m0 numeric(12,2),
  m1 numeric(12,2),
  m2 numeric(12,2),
  m3 numeric(12,2),
  m4 numeric(12,2),
  m5 numeric(12,2),
  m6 numeric(12,2),
  m7 numeric(12,2),
  p0 numeric(20,8),
  p1 numeric(20,8),
  p2 numeric(20,8),
  p3 numeric(20,8),
  p4 numeric(20,8),
  p5 numeric(20,8),
  p6 numeric(20,8),
  p7 numeric(20,8),
  u0 numeric,
  u1 numeric,
  u2 numeric,
  u3 numeric,
  u4 numeric,
  u5 numeric,
  u6 numeric,
  u7 numeric,
  t0 text,
  t1 text,
  t2 text,
  t3 text,
  t4 text,
  t5 text,
  t6 text,
  t7 text,
  k0 int8,
  k1 int8,
  k2 int8,
  k3 int8,
  d0 timestamptz,
  d1 timestamptz,
  f0 float8,
  f1 float8
);
DROP TABLE IF EXISTS toast;
CREATE TABLE toast (
  id bigint NOT NULL,
  p0 numeric(20,8),
  p1 numeric(20,8),
  u0 numeric,
  u1 numeric,
  payload text
);
ALTER TABLE toast ALTER COLUMN payload SET STORAGE EXTERNAL;
