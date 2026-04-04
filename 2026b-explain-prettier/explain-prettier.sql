
/*
 * Extract and round the total execution time from "actual time=X..Y" format.
 * Keeps only Y (total time), rounded to nearest integer.
 */
CREATE OR REPLACE FUNCTION _normalize_actual_time(line text)
RETURNS text LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE
  match text;
  total_time numeric;
  rounded_time integer;
BEGIN
  -- Extract the "actual time=X..Y" portion
  match := (regexp_matches(line, 'actual time=\d+\.\d+\.\.(\d+\.\d+)', 'g'))[1];
  IF match IS NOT NULL THEN
    total_time := match::numeric;
    rounded_time := round(total_time)::integer;
    -- Replace with rounded value
    RETURN regexp_replace(line,
      'actual time=\d+\.\d+\.\.\d+\.\d+',
      'actual time=' || rounded_time::text,
      'g');
  END IF;
  RETURN line;
END; $$;

/*
 * Normalise a single line of EXPLAIN output for regression stability.
 *
 * Platform-dependent masking (when platform_dependent=false, the default):
 *   - Memory sizes (kB/MB/GB) → NN
 *   - Floating-point row counts (N.00) → N
 *   - Volatile counters (Heap Fetches) → N
 *   - Hash allocation (Buckets, Batches) → N
 *   - Worker counts (Workers Planned, Workers Launched) → N
 *   - Wall-clock timings (actual time=X..Y) → actual time=Z (Y rounded to integer)
 *   - Planning/Execution Time → N ms
 * When platform_dependent=true, these values are exposed as-is.
 *
 * Elements shown/hidden (controlled by show_* parameters, all default false):
 *   - Cost estimates (cost=X..Y) → shown when show_cost=true
 *   - Width estimates (width=N) → shown when show_width=true
 *   - Loop counts (loops=N) → shown when show_loops=true
 *   - Detail lines (Buffers, Worker, Workers Planned/Launched, Buckets, Batches, Pre-sorted Groups, Heap Fetches, Sort Method, Cache Mode) → shown when show_details=true
 *
 * Lines matching "Index Searches:" (present only in PG 18+) return NULL to signal
 * they should be filtered out.
 *
 * This is an internal function used by pretty_explain_analyze() and
 * pretty_explain_text(). Exposed for flexibility but not part of the public API.
 */
CREATE OR REPLACE FUNCTION _normalize_explain_line(
  line text,
  platform_dependent boolean DEFAULT false,
  show_cost boolean DEFAULT false,
  show_width boolean DEFAULT false,
  show_loops boolean DEFAULT false,
  show_details boolean DEFAULT false
)
RETURNS text LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE
  out_line text;
BEGIN
  out_line := line;
  -- Mask platform-dependent and volatile values unless platform_dependent=true exposes them
  IF NOT platform_dependent THEN
    -- Mask memory sizes: kB, MB, GB. These appear as "Memory Usage: 42kB" or
    -- "Memory: 42kB" (unquoted metric field names). Match only these specific
    -- patterns to avoid masking user data (e.g. quoted identifier "Memory: 42kB").
    out_line := regexp_replace(out_line, '(Memory Usage:\s*)\d+kB', '\1NN', 'g');
    out_line := regexp_replace(out_line, '(Memory Usage:\s*)\d+MB', '\1NN', 'g');
    out_line := regexp_replace(out_line, '(Memory Usage:\s*)\d+GB', '\1NN', 'g');
    out_line := regexp_replace(out_line, '(Memory:\s*)\d+kB', '\1NN', 'g');
    out_line := regexp_replace(out_line, '(Memory:\s*)\d+MB', '\1NN', 'g');
    out_line := regexp_replace(out_line, '(Memory:\s*)\d+GB', '\1NN', 'g');
    -- Mask floating-point row counts emitted by some plan nodes
    out_line := regexp_replace(out_line, 'rows=(\d+)\.00', 'rows=\1', 'g');
    -- Mask volatile counters
    out_line := regexp_replace(out_line, '(Heap Fetches:) \d+', '\1 N', 'g');
    -- Mask hash node allocation (platform-dependent)
    out_line := regexp_replace(out_line, '(Buckets:) \d+', '\1 N', 'g');
    out_line := regexp_replace(out_line, '(Batches:) \d+', '\1 N', 'g');
    -- Mask worker counts (platform-dependent allocation)
    out_line := regexp_replace(out_line, '(Workers Planned:) \d+', '\1 N', 'g');
    out_line := regexp_replace(out_line, '(Workers Launched:) \d+', '\1 N', 'g');
    -- Mask wall-clock timings (present when TIMING is enabled): keep only
    -- the total time (second value after ..), rounded to nearest integer.
    -- Use a helper function to extract and round the value properly.
    out_line := _normalize_actual_time(out_line);
  END IF;
  -- Strip cost estimates if show_cost is false
  IF NOT show_cost THEN
    out_line := regexp_replace(out_line, 'cost=\d+\.\d+\.\.\d+\.\d+\s*', '', 'g');
  END IF;
  -- Strip width estimates if show_width is false
  IF NOT show_width THEN
    out_line := regexp_replace(out_line, '\s+width=\d+', '', 'g');
  END IF;
  -- Strip loop counts if show_loops is false
  IF NOT show_loops THEN
    out_line := regexp_replace(out_line, '\s+loops=\d+', '', 'g');
  END IF;
  -- Signal that Index Searches lines should be filtered out (PG 18+ only)
  IF out_line ~ '^\s*Index Searches:' THEN
    RETURN NULL;
  END IF;
  -- Filter out detail lines if show_details is false
  IF NOT show_details THEN
    IF out_line ~ '^\s*Buffers:' OR
       out_line ~ '^\s*Worker \d+:' OR
       out_line ~ '^\s*Workers Planned:' OR
       out_line ~ '^\s*Workers Launched:' OR
       out_line ~ '^\s*Buckets:' OR
       out_line ~ '^\s*Batches:' OR
       out_line ~ '^\s*Pre-sorted Groups:' OR
       out_line ~ '^\s*Heap Fetches:' OR
       out_line ~ '^\s*Sort Method:' OR
       out_line ~ '^\s*Cache Mode:' THEN
      RETURN NULL;
    END IF;
  END IF;
  RETURN out_line;
END; $$;

/*
 * Execute EXPLAIN on a query and return normalised, regression-stable output.
 *
 * Primary purpose: produce plan text that is identical across PostgreSQL
 * versions and platforms so regression test expected files do not need to be
 * updated for every minor formatting change.
 *
 * The optional `params` argument is passed verbatim inside EXPLAIN (...), so
 * callers can request additional options (e.g. 'ANALYZE, COSTS OFF') without
 * losing the normalisation step.  The default options suppress all
 * execution-time noise (timing, buffers, summary) while still running the
 * query so that actual-rows figures are available.
 */
CREATE OR REPLACE FUNCTION pretty_explain_analyze(
  query text,
  params text DEFAULT 'ANALYZE, COSTS OFF, TIMING OFF, SUMMARY OFF, BUFFERS OFF',
  platform_dependent boolean DEFAULT false,
  show_cost boolean DEFAULT false,
  show_width boolean DEFAULT false,
  show_loops boolean DEFAULT false,
  show_details boolean DEFAULT false
)
RETURNS TABLE (out_line text) LANGUAGE plpgsql AS $$
DECLARE
  line text;
  normalized text;
BEGIN
  IF query IS NULL OR btrim(query) = '' THEN
    RAISE EXCEPTION 'pretty_explain_analyze: query must not be NULL or empty';
  END IF;
  IF params IS NULL OR btrim(params) = '' THEN
    RAISE EXCEPTION 'pretty_explain_analyze: params must not be NULL or empty';
  END IF;

  FOR line IN
    EXECUTE 'EXPLAIN (' || params || ') ' || query
  LOOP
    normalized := _normalize_explain_line(line, platform_dependent, show_cost,
										  show_width, show_loops, show_details);
    IF normalized IS NOT NULL THEN
      out_line := normalized;
      RETURN next;
    END IF;
  END LOOP;
END; $$;

/*
 * Normalise raw EXPLAIN output (copy/pasted text) for regression stability.
 *
 * Takes the full multi-line EXPLAIN output text (as you'd copy from psql),
 * splits by newlines, applies the same normalisations as pretty_explain_analyze(),
 * and returns one line per row.
 *
 * Useful for comparing pre-captured EXPLAIN output without re-executing the
 * query. Simply copy/paste the EXPLAIN output as a multi-line string.
 *
 * Example:
 *   SELECT pretty_explain_text($$Seq Scan on t1 (cost=0.00..1.00 rows=100)
 *     Memory Usage: 42kB$$);
 */
CREATE OR REPLACE FUNCTION pretty_explain_text(
  explain_text text,
  platform_dependent boolean DEFAULT false,
  show_cost boolean DEFAULT false,
  show_width boolean DEFAULT false,
  show_loops boolean DEFAULT false,
  show_details boolean DEFAULT false
)
RETURNS TABLE (out_line text) LANGUAGE plpgsql AS $$
DECLARE
  line text;
  normalized text;
BEGIN
  IF explain_text IS NULL OR btrim(explain_text) = '' THEN
    RAISE EXCEPTION 'pretty_explain_text: explain_text must not be NULL or empty';
  END IF;

  FOR line IN
    SELECT regexp_split_to_table(explain_text, '\n')
  LOOP
    normalized := _normalize_explain_line(line, platform_dependent, show_cost,
										  show_width, show_loops, show_details);
    IF normalized IS NOT NULL THEN
      out_line := normalized;
      RETURN next;
    END IF;
  END LOOP;
END; $$;

COMMENT ON FUNCTION pretty_explain_analyze(text, text, boolean, boolean, boolean, boolean, boolean) IS
  'Run EXPLAIN on query and return plan lines normalised for stable regression output. '
  'When platform_dependent=true, masks memory sizes, floating-point row counts, '
  'hash allocation (Buckets/Batches), worker counts (Workers Planned/Launched), and wall-clock timings. '
  'The optional params argument overrides the default EXPLAIN options. '
  'When show_cost=true, cost estimates are shown. '
  'When show_width=true, width estimates are shown. '
  'When show_loops=true, loop counts are shown. '
  'When show_details=true, detail lines (Buffers, Workers, Buckets, Batches, Pre-sorted Groups, Heap Fetches, Sort Method, Cache Mode) are shown.';

COMMENT ON FUNCTION pretty_explain_text(text, boolean, boolean, boolean, boolean, boolean) IS
  'Normalise copy/pasted raw EXPLAIN output for stable regression comparison. '
  'Takes multi-line EXPLAIN text, applies the same filtering and masking as '
  'pretty_explain_analyze(), and returns one normalised line per row. '
  'When platform_dependent=true, masks memory sizes, floating-point row counts, '
  'hash allocation (Buckets/Batches), worker counts (Workers Planned/Launched), and wall-clock timings. '
  'When show_cost=true, cost estimates are shown. '
  'When show_width=true, width estimates are shown. '
  'When show_loops=true, loop counts are shown. '
  'When show_details=true, detail lines (Buffers, Workers, Buckets, Batches, Pre-sorted Groups, Heap Fetches, Sort Method, Cache Mode) are shown. '
  'Typical workflow: run EXPLAIN in psql, copy the output, then call: '
  'SELECT pretty_explain_text($$[paste EXPLAIN output here]$$);';