DROP INDEX IF EXISTS movie_link_movie_id_linked_movie_id_idx,
  movie_companies_movie_id_idx,
  movie_info_idx_movie_id_idx,
  title_id_kind_id_idx,
  movie_info_idx_movie_id_info_type_id_idx,
  movie_info_idx_info_type_id_movie_id_idx,
  movie_link_linked_movie_id_movie_id_idx,
  movie_keyword_movie_id_idx,
  movie_companies_note_idx,
  movie_info_info_gin_movie_id_idx;

/*
 * Second stage of analysis revealed the following indexes:
 * (for parameterised joins)
 */
CREATE INDEX movie_link_movie_id_linked_movie_id_idx ON movie_link (movie_id, linked_movie_id);
CREATE INDEX movie_companies_movie_id_idx ON movie_companies (movie_id);
CREATE INDEX movie_info_idx_movie_id_idx ON movie_info_idx (movie_id);
CREATE INDEX title_id_kind_id_idx ON title (id, kind_id);

/*
 * One more analysis iteration.
 */
CREATE INDEX movie_info_idx_movie_id_info_type_id_idx ON movie_info_idx (movie_id, info_type_id);

CREATE INDEX movie_info_idx_info_type_id_movie_id_idx ON movie_info_idx (info_type_id, movie_id);
CREATE INDEX movie_link_linked_movie_id_movie_id_idx ON movie_link (linked_movie_id, movie_id);

/*
 * Third
 */
CREATE INDEX movie_keyword_movie_id_idx ON movie_keyword (movie_id);
CREATE INDEX movie_companies_note_idx ON movie_companies (note);

-- That's is a stopper
CREATE EXTENSION IF NOT EXISTS btree_gin;
CREATE INDEX movie_info_info_gin_movie_id_idx ON movie_info USING gin (info gin_trgm_ops, movie_id);