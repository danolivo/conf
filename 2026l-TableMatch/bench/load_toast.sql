INSERT INTO toast SELECT g,
  (hashint8extended(g, 80) % 1000000000000000000)::numeric / 100000000,
  (hashint8extended(g, 81) % 1000000000000000000)::numeric / 100000000,
  round(hashint8extended(g, 82)::numeric / 7, 12),
  round(hashint8extended(g, 83)::numeric / 7, 12),
  repeat(md5(g::text || '-p'), 64 + (g % 65)::int)
FROM generate_series(:lo::bigint, :hi::bigint) g;
