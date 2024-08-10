COPY power_plants
FROM '/Users/danolivo/Library/CloudStorage/Dropbox/Databases/global_power_plant_database_v_1_3/global_power_plant_database.csv'
WITH (FORMAT csv, HEADER, NULL '', DELIMITER ',', QUOTE '"', ESCAPE '\', ENCODING 'UTF8');
VACUUM ANALYZE power_plants;
