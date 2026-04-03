-- Real-life example: Top-10 most popular products with type-specific properties
-- This demonstrates the pre-sorted scan optimization in PG18.

DROP TABLE IF EXISTS electronics_props, clothing_props, food_props, products CASCADE;

-- Main products table (large)
CREATE TABLE products (
    id          int PRIMARY KEY,
    name        text NOT NULL,
    category    text NOT NULL,  -- 'electronics', 'clothing', 'food', ...
    popularity  int NOT NULL,   -- sales count or rating score
    price       numeric(10,2)
);

-- Type-specific property tables
CREATE TABLE electronics_props (
    product_id  int PRIMARY KEY REFERENCES products(id),
    warranty_months int,
    voltage     text,
    wifi        boolean
);

CREATE TABLE clothing_props (
    product_id  int PRIMARY KEY REFERENCES products(id),
    size        text,
    color       text,
    material    text
);

CREATE TABLE food_props (
    product_id  int PRIMARY KEY REFERENCES products(id),
    expiry_days int,
    organic     boolean,
    allergens   text
);

-- Populate products: 100k rows, ~33k per category
INSERT INTO products
SELECT
    g,
    'Product_' || g,
    CASE (g % 3) WHEN 0 THEN 'electronics'
                 WHEN 1 THEN 'clothing'
                 ELSE 'food' END,
    (random() * 10000)::int,   -- popularity 0..10000
    (random() * 500 + 1)::numeric(10,2)
FROM generate_series(1, 100000) g;

-- Populate property tables for matching categories
INSERT INTO electronics_props
SELECT id, (random()*36)::int, '220V', (random() > 0.5)
FROM products WHERE category = 'electronics';

INSERT INTO clothing_props
SELECT id,
    (ARRAY['S','M','L','XL'])[1 + (random()*3)::int],
    (ARRAY['red','blue','black','white'])[1 + (random()*3)::int],
    (ARRAY['cotton','polyester','wool'])[1 + (random()*2)::int]
FROM products WHERE category = 'clothing';

INSERT INTO food_props
SELECT id, (random()*365)::int, (random() > 0.5),
    (ARRAY['nuts','gluten','dairy',NULL])[1 + (random()*3)::int]
FROM products WHERE category = 'food';

VACUUM ANALYZE;

-- The query: top-10 most popular products with all their properties as JSON
EXPLAIN (ANALYZE, COSTS OFF)
SELECT
    p.id,
    p.name,
    p.category,
    p.popularity,
    p.price,
    json_strip_nulls(json_build_object(
        'warranty_months', e.warranty_months,
        'voltage',         e.voltage,
        'wifi',            e.wifi,
        'size',            c.size,
        'color',           c.color,
        'material',        c.material,
        'expiry_days',     f.expiry_days,
        'organic',         f.organic,
        'allergens',       f.allergens
    )) AS properties
FROM products p
    LEFT JOIN electronics_props e ON e.product_id = p.id
    LEFT JOIN clothing_props    c ON c.product_id = p.id
    LEFT JOIN food_props        f ON f.product_id = p.id
ORDER BY p.popularity DESC
LIMIT 10;

/*
 Limit (actual time=43.924..44.176 rows=10.00 loops=1)
   Buffers: shared hit=940
   ->  Nested Loop Left Join (actual time=43.922..44.172 rows=10.00 loops=1)
         Buffers: shared hit=940
         ->  Nested Loop Left Join (actual time=43.865..43.980 rows=10.00 loops=1)
               Buffers: shared hit=918
               ->  Nested Loop Left Join (actual time=43.851..43.903 rows=10.00 loops=1)
                     Buffers: shared hit=892
                     ->  Sort (actual time=43.825..43.826 rows=10.00 loops=1)
                           Sort Key: p.popularity DESC
                           Sort Method: top-N heapsort  Memory: 26kB
                           Buffers: shared hit=870
                           ->  Seq Scan on products p (actual time=0.016..9.847 rows=100000.00 loops=1)
                                 Buffers: shared hit=870
                     ->  Index Scan using electronics_props_pkey on electronics_props e (actual time=0.006..0.006 rows=0.20 loops=10)
                           Index Cond: (product_id = p.id)
                           Index Searches: 10
                           Buffers: shared hit=22
               ->  Index Scan using clothing_props_pkey on clothing_props c (actual time=0.007..0.007 rows=0.60 loops=10)
                     Index Cond: (product_id = p.id)
                     Index Searches: 10
                     Buffers: shared hit=26
         ->  Index Scan using food_props_pkey on food_props f (actual time=0.006..0.006 rows=0.20 loops=10)
               Index Cond: (product_id = p.id)
               Index Searches: 10
               Buffers: shared hit=22
 Planning:
   Buffers: shared hit=36
 Planning Time: 2.150 ms
 Execution Time: 44.305 ms
(30 rows)

 Limit (actual time=813.491..813.495 rows=10.00 loops=1)
   Buffers: shared hit=1442
   ->  Sort (actual time=813.489..813.491 rows=10.00 loops=1)
         Sort Key: p.popularity DESC
         Sort Method: top-N heapsort  Memory: 27kB
         Buffers: shared hit=1442
         ->  Hash Left Join (actual time=73.483..772.134 rows=100000.00 loops=1)
               Hash Cond: (p.id = f.product_id)
               Buffers: shared hit=1442
               ->  Hash Left Join (actual time=54.732..128.615 rows=100000.00 loops=1)
                     Hash Cond: (p.id = c.product_id)
                     Buffers: shared hit=1261
                     ->  Hash Left Join (actual time=32.330..79.951 rows=100000.00 loops=1)
                           Hash Cond: (p.id = e.product_id)
                           Buffers: shared hit=1051
                           ->  Seq Scan on products p (actual time=0.036..6.171 rows=100000.00 loops=1)
                                 Buffers: shared hit=870
                           ->  Hash (actual time=32.189..32.189 rows=33333.00 loops=1)
                                 Buckets: 65536  Batches: 1  Memory Usage: 2075kB
                                 Buffers: shared hit=181
                                 ->  Seq Scan on electronics_props e (actual time=0.028..12.981 rows=33333.00 loops=1)
                                       Buffers: shared hit=181
                     ->  Hash (actual time=22.354..22.354 rows=33334.00 loops=1)
                           Buckets: 65536  Batches: 1  Memory Usage: 2247kB
                           Buffers: shared hit=210
                           ->  Seq Scan on clothing_props c (actual time=0.018..8.800 rows=33334.00 loops=1)
                                 Buffers: shared hit=210
               ->  Hash (actual time=18.680..18.681 rows=33333.00 loops=1)
                     Buckets: 65536  Batches: 1  Memory Usage: 2054kB
                     Buffers: shared hit=181
                     ->  Seq Scan on food_props f (actual time=0.008..7.573 rows=33333.00 loops=1)
                           Buffers: shared hit=181
 Planning:
   Buffers: shared hit=73
 Planning Time: 3.966 ms
 Execution Time: 813.815 ms
(36 rows)

 */
