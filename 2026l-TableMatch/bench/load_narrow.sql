INSERT INTO narrow SELECT g,
  ((hashint8extended(g, 1) & 9223372036854775807) % 10000000000)::numeric / 100,
  (hashint8extended(g, 2) % 1000000000000000000)::numeric / 100000000,
  round(hashint8extended(g, 3)::numeric / 7, 12),
  hashint8(g),
  timestamptz '2020-01-01 00:00:00+00' + ((hashint8extended(g, 4) & 9223372036854775807) % 157680000) * interval '1 second'
FROM generate_series(:lo::bigint, :hi::bigint) g;
