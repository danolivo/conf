
DROP INDEX movie_link_movie_id_linked_movie_id_idx,
  movie_info_idx_movie_id_info_type_id_idx;
  
CREATE INDEX aka_name_idx_2 ON aka_name (name);
CREATE INDEX movie_info_idx_idx_1 ON movie_info_idx (info);
CREATE INDEX title_idx_1 ON title (production_year);

CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX idx_movie_companies ON movie_companies USING gin (note gin_trgm_ops);
CREATE INDEX cast_info_idx_1 ON cast_info USING gin (note gin_trgm_ops);
CREATE INDEX idx_movie_info ON movie_info USING gin (info gin_trgm_ops);
CREATE INDEX keyword_idx_1 ON keyword USING gin (keyword gin_trgm_ops);
CREATE INDEX info_type_idx_1 ON info_type USING gin (info gin_trgm_ops);
CREATE INDEX company_name_idx_1 ON company_name USING gin (country_code gin_trgm_ops);
CREATE INDEX person_info_note ON person_info (note);

/*
 * Second stage of analysis revealed the following indexes:
 * (for parameterised joins)
 */
CREATE INDEX ON movie_link (movie_id, linked_movie_id);
CREATE INDEX ON movie_companies(movie_id);
CREATE INDEX ON movie_info_idx(movie_id);
CREATE INDEX ON title(id,kind_id);

/*
 * One more analysis iteration.
 */
CREATE INDEX ON movie_info_idx(movie_id,info_type_id);

CREATE INDEX movie_info_idx1 ON movie_info_idx(info_type_id,movie_id);
CREATE INDEX movie_info_idx2 ON movie_link (linked_movie_id,movie_id);


/*
 * Third
 */
CREATE INDEX movie_keyword1 ON movie_keyword(movie_id);
CREATE INDEX movie_companies1 ON movie_companies (note);

-- That's is a stopper
CREATE EXTENSION IF NOT EXISTS btree_gin;
CREATE INDEX idx_movie_info2 ON movie_info USING gin (info gin_trgm_ops,movie_id);
