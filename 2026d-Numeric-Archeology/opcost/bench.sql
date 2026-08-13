-- Operator cost matrix for the types a 1C database actually uses.
--
-- Operand widths are taken from the statistics of erp_v / cherkizovo, so the
-- numbers describe the comparisons that workload really performs:
--
--   numeric   median 3 bytes, p75 5, p95 6, max 12
--   bytea     p25 5 bytes (4-byte TRef), median/p75 17 (16-byte RRef)
--   mvarchar  median ~9 bytes, p95 ~125
--   mchar     median 27 bytes
--   timestamp 8, integer 4, boolean 1
--
-- Every measurement is nanoseconds per call, executor excluded. Run with
--   psql -d synth -f bench.sql

\pset footer off
\timing off

select round(opcost_overhead(10000000)::numeric, 2) as empty_loop_ns \gset floor_

\echo measurement floor (empty loop), ns:
select :'floor_empty_loop_ns' as floor_ns;

with cases(ord, grp, label, func, typname, a, b) as (values
  -- ---- baseline -----------------------------------------------------------
  ( 1, 'int4',      '= equal',        'int4eq',            'int4',      '42', '42'),
  ( 2, 'int4',      '= differ',       'int4eq',            'int4',      '42', '43'),
  ( 3, 'int4',      '<>',             'int4ne',            'int4',      '42', '43'),
  ( 4, 'int4',      '<',              'int4lt',            'int4',      '42', '43'),
  ( 5, 'int4',      'btree cmp',      'btint4cmp',         'int4',      '42', '43'),
  ( 6, 'int4',      'hash',           'hashint4',          'int4',      '42', '42'),

  -- ---- boolean ------------------------------------------------------------
  (10, 'bool',      '= equal',        'booleq',            'bool',      't',  't'),
  (11, 'bool',      '<',              'boollt',            'bool',      'f',  't'),
  (12, 'bool',      'btree cmp',      'btboolcmp',         'bool',      'f',  't'),

  -- ---- timestamp ----------------------------------------------------------
  (20, 'timestamp', '= equal',        'timestamp_eq',      'timestamp', '2026-01-01 10:00:00', '2026-01-01 10:00:00'),
  (21, 'timestamp', '= differ',       'timestamp_eq',      'timestamp', '2026-01-01 10:00:00', '2026-01-02 10:00:00'),
  (22, 'timestamp', '<',              'timestamp_lt',      'timestamp', '2026-01-01 10:00:00', '2026-01-02 10:00:00'),
  (23, 'timestamp', 'btree cmp',      'timestamp_cmp',     'timestamp', '2026-01-01 10:00:00', '2026-01-02 10:00:00'),
  (24, 'timestamp', 'hash',           'timestamp_hash',    'timestamp', '2026-01-01 10:00:00', '2026-01-01 10:00:00'),

  -- ---- numeric, 3 bytes (the median width in both 1C databases) ----------
  (30, 'numeric3',  '= equal',        'numeric_eq',        'numeric',   '1', '1'),
  (31, 'numeric3',  '= differ',       'numeric_eq',        'numeric',   '1', '2'),
  (32, 'numeric3',  '<>',             'numeric_ne',        'numeric',   '1', '2'),
  (33, 'numeric3',  '<',              'numeric_lt',        'numeric',   '1', '2'),
  (34, 'numeric3',  'btree cmp',      'numeric_cmp',       'numeric',   '1', '2'),
  (35, 'numeric3',  'hash',           'hash_numeric',      'numeric',   '1', '1'),

  -- ---- numeric, 5 bytes (p75) and a money value (numeric(15,2)) ----------
  (40, 'numeric5',  '= equal',        'numeric_eq',        'numeric',   '12345', '12345'),
  (41, 'numeric5',  '= differ',       'numeric_eq',        'numeric',   '12345', '12346'),
  (42, 'numeric5',  '<',              'numeric_lt',        'numeric',   '12345', '12346'),
  (43, 'numeric5',  'btree cmp',      'numeric_cmp',       'numeric',   '12345', '12346'),
  (50, 'numeric_money', '= equal',    'numeric_eq',        'numeric',   '12345.67', '12345.67'),
  (51, 'numeric_money', '= differ',   'numeric_eq',        'numeric',   '12345.67', '12345.68'),
  (52, 'numeric_money', '<',          'numeric_lt',        'numeric',   '12345.67', '12345.68'),
  (53, 'numeric_money', 'hash',       'hash_numeric',      'numeric',   '12345.67', '12345.67'),
  -- equal value, different display scale: the memcmp shortcut cannot fire
  (54, 'numeric_scale', '= equal/diff scale', 'numeric_eq','numeric',   '1.50', '1.5'),

  -- ---- bytea, 5 bytes = 4-byte TRef ---------------------------------------
  (60, 'bytea5',    '= equal',        'byteaeq',           'bytea',     '\x00000123', '\x00000123'),
  (61, 'bytea5',    '= differ 1st',   'byteaeq',           'bytea',     '\x00000123', '\xff000123'),
  (62, 'bytea5',    '<',              'bytealt',           'bytea',     '\x00000123', '\x00000124'),
  (63, 'bytea5',    'btree cmp',      'byteacmp',          'bytea',     '\x00000123', '\x00000124'),
  (64, 'bytea5',    'hash',           'hashbytea',         'bytea',     '\x00000123', '\x00000123'),

  -- ---- bytea, 17 bytes = 16-byte RRef, the median 1C reference -----------
  (70, 'bytea17',   '= equal',        'byteaeq',           'bytea',     '\xa0d9a9132b128869476ea3043299776f', '\xa0d9a9132b128869476ea3043299776f'),
  (71, 'bytea17',   '= differ 1st',   'byteaeq',           'bytea',     '\xa0d9a9132b128869476ea3043299776f', '\xffd9a9132b128869476ea3043299776f'),
  (72, 'bytea17',   '= differ last',  'byteaeq',           'bytea',     '\xa0d9a9132b128869476ea3043299776f', '\xa0d9a9132b128869476ea30432997700'),
  (73, 'bytea17',   '<',              'bytealt',           'bytea',     '\xa0d9a9132b128869476ea3043299776f', '\xa0d9a9132b128869476ea3043299777f'),
  (74, 'bytea17',   'btree cmp',      'byteacmp',          'bytea',     '\xa0d9a9132b128869476ea3043299776f', '\xa0d9a9132b128869476ea3043299777f'),
  (75, 'bytea17',   'hash',           'hashbytea',         'bytea',     '\xa0d9a9132b128869476ea3043299776f', '\xa0d9a9132b128869476ea3043299776f'),
  -- what a 1C reference comparison really looks like: TYPE || TRef, 5 bytes
  (76, 'bytea_zero','= equal all-00', 'byteaeq',           'bytea',     '\x00000000000000000000000000000000', '\x00000000000000000000000000000000'),

  -- ---- mvarchar, median ~9 bytes and p95 ~125 bytes ----------------------
  (80, 'mvarchar9', '= equal',        'mvarchar_icase_eq', 'mvarchar',  'Основной', 'Основной'),
  (81, 'mvarchar9', '= differ 1st',   'mvarchar_icase_eq', 'mvarchar',  'Основной', 'Xсновной'),
  (82, 'mvarchar9', '<',              'mvarchar_icase_lt', 'mvarchar',  'Основной', 'Отгрузка'),
  (83, 'mvarchar9', 'btree cmp',      'mvarchar_icase_cmp','mvarchar',  'Основной', 'Отгрузка'),
  (84, 'mvarchar9', 'hash',           'mvarchar_hash',     'mvarchar',  'Основной', 'Основной'),
  (90, 'mvarchar125','= equal',       'mvarchar_icase_eq', 'mvarchar',  'Поступление товаров и услуг от поставщика по договору номер 12345 от 01.01.2026 склад Центральный ответственный', 'Поступление товаров и услуг от поставщика по договору номер 12345 от 01.01.2026 склад Центральный ответственный'),
  (91, 'mvarchar125','= differ last', 'mvarchar_icase_eq', 'mvarchar',  'Поступление товаров и услуг от поставщика по договору номер 12345 от 01.01.2026 склад Центральный ответственный', 'Поступление товаров и услуг от поставщика по договору номер 12345 от 01.01.2026 склад Центральный ответственныX'),
  (92, 'mvarchar125','<',             'mvarchar_icase_lt', 'mvarchar',  'Поступление товаров и услуг от поставщика по договору номер 12345 от 01.01.2026 склад Центральный ответственный', 'Реализация товаров и услуг покупателю по договору номер 54321 от 02.02.2026 склад Основной ответственный'),
  (93, 'mvarchar125','hash',          'mvarchar_hash',     'mvarchar',  'Поступление товаров и услуг от поставщика по договору номер 12345 от 01.01.2026 склад Центральный ответственный', 'Поступление товаров и услуг от поставщика по договору номер 12345 от 01.01.2026 склад Центральный ответственный'),

  -- ---- mchar, median 27 bytes ---------------------------------------------
  (100,'mchar27',   '= equal',        'mchar_icase_eq',    'mchar',     'Приходная накладная номер', 'Приходная накладная номер'),
  (101,'mchar27',   '= differ 1st',   'mchar_icase_eq',    'mchar',     'Приходная накладная номер', 'Xриходная накладная номер'),
  (102,'mchar27',   '<',              'mchar_icase_lt',    'mchar',     'Приходная накладная номер', 'Расходная накладная номер'),
  (103,'mchar27',   'btree cmp',      'mchar_icase_cmp',   'mchar',     'Приходная накладная номер', 'Расходная накладная номер'),
  (104,'mchar27',   'hash',           'mchar_hash',        'mchar',     'Приходная накладная номер', 'Приходная накладная номер'),

  -- ---- text, for reference: the type 1C does NOT use ----------------------
  (110,'text',      '= equal',        'texteq',            'text',      'Основной', 'Основной'),
  (111,'text',      '<',              'text_lt',           'text',      'Основной', 'Отгрузка'),
  (112,'text',      'btree cmp',      'bttextcmp',         'text',      'Основной', 'Отгрузка')
)
select grp,
       label,
       round(opcost_bench(func::regproc, typname::regtype, a, b, 10000000)::numeric, 2) as ns
from cases
order by ord;
