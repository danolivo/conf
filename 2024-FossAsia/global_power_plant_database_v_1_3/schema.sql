ALTER SYSTEM SET default_statistics_target TO 1000;
SELECT pg_reload_conf();

CREATE TABLE power_plants (
  country                        varchar(3), -- 3 character country code corresponding to the ISO 3166-1 alpha-3 specification
  country_long                   text,       -- longer form of the country designation
  name                           text,       -- name or title of the power plant, generally in Romanized form
  gppd_idnr                      text,       -- 10 or 12 character identifier for the power plant
  capacity_mw                    numeric,    -- electrical generating capacity in megawatts
  latitude                       numeric,    -- geolocation in decimal degrees; WGS84 (EPSG:4326)
  longitude                      numeric,    -- geolocation in decimal degrees; WGS84 (EPSG:4326)
  primary_fuel                   text,       -- energy source used in primary electricity generation or export
  other_fuel1                    text,       -- energy source used in electricity generation or export
  other_fuel2                    text,       -- energy source used in electricity generation or export
  other_fuel3                    text,       -- energy source used in electricity generation or export
  commissioning_year             numeric,    -- year of plant operation, weighted by unit-capacity when data is available
  owner                          text,       -- majority shareholder of the power plant, generally in Romanized form
  source                         text,       -- entity reporting the data; could be an organization, report, or document, generally in Romanized form
  url                            text,       -- web document corresponding to the `source` field
  geolocation_source             text,       -- attribution for geolocation information
  wepp_id                        text,       -- a reference to a unique plant identifier in the widely-used PLATTS-WEPP database.
  year_of_capacity_data          numeric,    -- year the capacity information was reported
  generation_gwh_2013            numeric,    -- electricity generation in gigawatt-hours reported for the year 2013
  generation_gwh_2014            numeric,    -- electricity generation in gigawatt-hours reported for the year 2014
  generation_gwh_2015            numeric,    -- electricity generation in gigawatt-hours reported for the year 2015
  generation_gwh_2016            numeric,    -- electricity generation in gigawatt-hours reported for the year 2016
  generation_gwh_2017            numeric,    -- electricity generation in gigawatt-hours reported for the year 2017
  generation_gwh_2018            numeric,    -- electricity generation in gigawatt-hours reported for the year 2018
  generation_gwh_2019            numeric,    -- electricity generation in gigawatt-hours reported for the year 2019
  generation_data_source         text,       -- attribution for the reported generation information
  estimated_generation_gwh_2013  numeric,    -- estimated electricity generation in gigawatt-hours for the year 2013 (see [2])
  estimated_generation_gwh_2014  numeric,    -- estimated electricity generation in gigawatt-hours for the year 2014 (see [2])
  estimated_generation_gwh_2015  numeric,    -- estimated electricity generation in gigawatt-hours for the year 2015 (see [2])
  estimated_generation_gwh_2016  numeric,    -- estimated electricity generation in gigawatt-hours for the year 2016 (see [2])
  estimated_generation_gwh_2017  numeric,    -- estimated electricity generation in gigawatt-hours for the year 2017 (see [2])
  estimated_generation_note_2013 text,       -- label of the model/method used to estimate generation for the year 2013 (see section on this field below)
  estimated_generation_note_2014 text,       -- label of the model/method used to estimate generation for the year 2014 (see section on this field below)
  estimated_generation_note_2015 text,       -- label of the model/method used to estimate generation for the year 2015 (see section on this field below)
  estimated_generation_note_2016 text,       -- label of the model/method used to estimate generation for the year 2016 (see section on this field below)
  estimated_generation_note_2017 text        -- label of the model/method used to estimate generation for the year 2017 (see section on this field below)
);