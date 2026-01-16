.mode csv
.separator ","

-- Import scalar data first
.import entity_slim_scalar.csv entity_text_temp

-- Split into text and data tables
INSERT INTO entity_text (id, label, description)
SELECT id, label, description FROM entity_text_temp WHERE id != 'id';

INSERT INTO entity_data (id, has_child, latitude, longitude)
SELECT id, 
       CASE WHEN has_child = 'true' THEN 1 ELSE 0 END,
       NULLIF(latitude, ''),
       NULLIF(longitude, '')
FROM entity_text_temp WHERE id != 'id';

DROP TABLE entity_text_temp;

-- Import relationships
.import entity_slim_instance_of.csv instance_of_temp
INSERT INTO instance_of (id, instance_of) 
SELECT id, instance_of FROM instance_of_temp WHERE id != 'id';
DROP TABLE instance_of_temp;

.import entity_slim_subclass_of.csv subclass_of_temp
INSERT INTO subclass_of (id, subclass_of) 
SELECT id, subclass_of FROM subclass_of_temp WHERE id != 'id';
DROP TABLE subclass_of_temp;

.import entity_slim_part_of.csv part_of_temp
INSERT INTO part_of (id, part_of) 
SELECT id, part_of FROM part_of_temp WHERE id != 'id';
DROP TABLE part_of_temp;

.import entity_slim_said_to_be_the_same_as.csv same_as_temp
INSERT INTO said_to_be_same_as (id, said_to_be_same_as) 
SELECT id, said_to_be_the_same_as FROM same_as_temp WHERE id != 'id';
DROP TABLE same_as_temp;

-- Optimize database
PRAGMA page_size = 1024;
VACUUM;
ANALYZE;
PRAGMA auto_vacuum = FULL;

-- Verify compression
.print "Database optimized"



--FTS5 index build
PRAGMA journal_mode=WAL;
PRAGMA synchronous=NORMAL;
PRAGMA temp_store=MEMORY;
PRAGMA locking_mode=EXCLUSIVE;
PRAGMA cache_size=-2000000; 
PRAGMA wal_autocheckpoint=1000;
INSERT INTO entity_text_fts(entity_text_fts) VALUES('rebuild');
.print "Done"

