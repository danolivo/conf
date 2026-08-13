-- Operator cost at the *average* operand widths of a 1C database.
--
-- Widths come from pg_statistic on erp_v and cherkizovo (they agree):
--   numeric    median 3 B, p75 5 B      -> '1' and '12345'
--   bytea      p25 5 B, median 17 B     -> 4-byte TRef and 16-byte RRef
--   mvarchar   median ~9 B              -> 4 Cyrillic characters
--   mchar      median 27 B              -> 13 Cyrillic characters
--   timestamp  8 B, integer 4 B, boolean 1 B
--
-- Operands are presented in the one-byte-header form that a tuple stores, which
-- is what the comparison functions actually receive when reading a 1C table.
-- opcost_width() in the output proves that, rather than asking to be believed.
--
-- Five repetitions per case; the minimum is the least contaminated estimate on a
-- box that also runs autovacuum, the median shows whether the minimum was luck.

\pset footer off

with cases(ord, typ, op, func, typname, a, b) as (values
  ( 1, 'int4',      '=  equal',   'int4eq',            'int4',      '42', '42'),
  ( 2, 'int4',      '=  differ',  'int4eq',            'int4',      '42', '43'),
  ( 3, 'int4',      '<',          'int4lt',            'int4',      '42', '43'),
  ( 4, 'int4',      'btree cmp',  'btint4cmp',         'int4',      '42', '43'),
  ( 5, 'int4',      'hash',       'hashint4',          'int4',      '42', '42'),

  (10, 'bool',      '=  equal',   'booleq',            'bool',      't',  't'),
  (11, 'bool',      '<',          'boollt',            'bool',      'f',  't'),
  (12, 'bool',      'btree cmp',  'btboolcmp',         'bool',      'f',  't'),

  (20, 'timestamp', '=  equal',   'timestamp_eq',      'timestamp', '2026-01-01 10:00:00', '2026-01-01 10:00:00'),
  (21, 'timestamp', '=  differ',  'timestamp_eq',      'timestamp', '2026-01-01 10:00:00', '2026-01-02 10:00:00'),
  (22, 'timestamp', '<',          'timestamp_lt',      'timestamp', '2026-01-01 10:00:00', '2026-01-02 10:00:00'),
  (23, 'timestamp', 'btree cmp',  'timestamp_cmp',     'timestamp', '2026-01-01 10:00:00', '2026-01-02 10:00:00'),
  (24, 'timestamp', 'hash',       'timestamp_hash',    'timestamp', '2026-01-01 10:00:00', '2026-01-01 10:00:00'),

  -- numeric at the median width: 3 bytes
  (30, 'numeric 3B', '=  equal',  'numeric_eq',        'numeric',   '1', '1'),
  (31, 'numeric 3B', '=  differ', 'numeric_eq',        'numeric',   '1', '2'),
  (32, 'numeric 3B', '<',         'numeric_lt',        'numeric',   '1', '2'),
  (33, 'numeric 3B', 'btree cmp', 'numeric_cmp',       'numeric',   '1', '2'),
  (34, 'numeric 3B', 'hash',      'hash_numeric',      'numeric',   '1', '1'),
  -- numeric at p75: 5 bytes
  (40, 'numeric 5B', '=  equal',  'numeric_eq',        'numeric',   '12345', '12345'),
  (41, 'numeric 5B', '=  differ', 'numeric_eq',        'numeric',   '12345', '12346'),
  (42, 'numeric 5B', '<',         'numeric_lt',        'numeric',   '12345', '12346'),
  (43, 'numeric 5B', 'btree cmp', 'numeric_cmp',       'numeric',   '12345', '12346'),

  -- bytea: the 4-byte TRef (p25) and the 16-byte RRef (median)
  (50, 'bytea 5B',  '=  equal',   'byteaeq',           'bytea',     '\x00000123', '\x00000123'),
  (51, 'bytea 5B',  '=  differ',  'byteaeq',           'bytea',     '\x00000123', '\x00000124'),
  (52, 'bytea 5B',  '<',          'bytealt',           'bytea',     '\x00000123', '\x00000124'),
  (53, 'bytea 5B',  'btree cmp',  'byteacmp',          'bytea',     '\x00000123', '\x00000124'),
  (54, 'bytea 5B',  'hash',       'hashbytea',         'bytea',     '\x00000123', '\x00000123'),
  (60, 'bytea 17B', '=  equal',   'byteaeq',           'bytea',     '\xa0d9a9132b128869476ea3043299776f', '\xa0d9a9132b128869476ea3043299776f'),
  (61, 'bytea 17B', '=  differ',  'byteaeq',           'bytea',     '\xa0d9a9132b128869476ea3043299776f', '\xffd9a9132b128869476ea3043299776f'),
  (62, 'bytea 17B', '<',          'bytealt',           'bytea',     '\xa0d9a9132b128869476ea3043299776f', '\xa0d9a9132b128869476ea3043299777f'),
  (63, 'bytea 17B', 'btree cmp',  'byteacmp',          'bytea',     '\xa0d9a9132b128869476ea3043299776f', '\xa0d9a9132b128869476ea3043299777f'),
  (64, 'bytea 17B', 'hash',       'hashbytea',         'bytea',     '\xa0d9a9132b128869476ea3043299776f', '\xa0d9a9132b128869476ea3043299776f'),

  -- mvarchar at the median width: 4 Cyrillic characters = 8 bytes of payload
  (70, 'mvarchar 9B', '=  equal',  'mvarchar_icase_eq', 'mvarchar', 'Осно', 'Осно'),
  (71, 'mvarchar 9B', '=  differ', 'mvarchar_icase_eq', 'mvarchar', 'Осно', 'Отгр'),
  (72, 'mvarchar 9B', '<',         'mvarchar_icase_lt', 'mvarchar', 'Осно', 'Отгр'),
  (73, 'mvarchar 9B', 'btree cmp', 'mvarchar_icase_cmp','mvarchar', 'Осно', 'Отгр'),
  (74, 'mvarchar 9B', 'hash',      'mvarchar_hash',     'mvarchar', 'Осно', 'Осно'),

  -- mchar at the median width: 13 Cyrillic characters = 26 bytes of payload
  (80, 'mchar 27B', '=  equal',   'mchar_icase_eq',    'mchar',     'Приходная нак', 'Приходная нак'),
  (81, 'mchar 27B', '=  differ',  'mchar_icase_eq',    'mchar',     'Приходная нак', 'Расходная нак'),
  (82, 'mchar 27B', '<',          'mchar_icase_lt',    'mchar',     'Приходная нак', 'Расходная нак'),
  (83, 'mchar 27B', 'btree cmp',  'mchar_icase_cmp',   'mchar',     'Приходная нак', 'Расходная нак'),
  (84, 'mchar 27B', 'hash',       'mchar_hash',        'mchar',     'Приходная нак', 'Приходная нак')
),
runs as (
  select c.*, opcost_bench(c.func::regproc, c.typname::regtype, c.a, c.b, 3000000) as ns
  from cases c cross join generate_series(1, 5) rep
)
select typ,
       op,
       opcost_width(typname::regtype, a) as bytes,
       round(min(ns)::numeric, 2) as min_ns,
       round(percentile_disc(0.5) within group (order by ns)::numeric, 2) as median_ns,
       round((100 * (max(ns) - min(ns)) / min(ns))::numeric, 0) as spread_pct
from runs
group by ord, typ, op, typname, a
order by ord;
