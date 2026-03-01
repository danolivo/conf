
DROP INDEX IF EXISTS aka_name_name_idx,
  movie_info_idx_info_idx,
  title_production_year_idx,
  movie_companies_note_gin_idx,
  cast_info_note_gin_idx,
  movie_info_info_gin_idx,
  keyword_keyword_gin_idx,
  info_type_info_gin_idx,
  company_name_country_code_gin_idx,
  person_info_note_idx;

CREATE INDEX aka_name_name_idx ON aka_name (name);
CREATE INDEX movie_info_idx_info_idx ON movie_info_idx (info);
CREATE INDEX title_production_year_idx ON title (production_year);

CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX movie_companies_note_gin_idx ON movie_companies USING gin (note gin_trgm_ops);
CREATE INDEX cast_info_note_gin_idx ON cast_info USING gin (note gin_trgm_ops);
CREATE INDEX movie_info_info_gin_idx ON movie_info USING gin (info gin_trgm_ops);
CREATE INDEX keyword_keyword_gin_idx ON keyword USING gin (keyword gin_trgm_ops);
CREATE INDEX info_type_info_gin_idx ON info_type USING gin (info gin_trgm_ops);
CREATE INDEX company_name_country_code_gin_idx ON company_name USING gin (country_code gin_trgm_ops);
CREATE INDEX person_info_note_idx ON person_info (note);
