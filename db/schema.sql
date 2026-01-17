CREATE TABLE entity_text (
    id TEXT PRIMARY KEY,
    label TEXT,
    description TEXT
);

CREATE TABLE entity_data (
    id TEXT PRIMARY KEY,
    has_child BOOLEAN,
    latitude REAL,
    longitude REAL
);

CREATE TABLE instance_of (
    id TEXT NOT NULL,
    instance_of TEXT NOT NULL
);

CREATE TABLE subclass_of (
    id TEXT NOT NULL,
    subclass_of TEXT NOT NULL
);

CREATE TABLE part_of (
    id TEXT NOT NULL,
    part_of TEXT NOT NULL
);

CREATE TABLE said_to_be_same_as (
    id TEXT NOT NULL,
    said_to_be_same_as TEXT NOT NULL
);

CREATE INDEX idx_instance_of_id ON instance_of(id);
CREATE INDEX idx_instance_of_instance_of ON instance_of(instance_of);
CREATE INDEX idx_subclass_of_id ON subclass_of(id);
CREATE INDEX idx_subclass_of_subclass_of ON subclass_of(subclass_of);
CREATE INDEX idx_part_of_id ON part_of(id);
CREATE INDEX idx_part_of_part_of ON part_of(part_of);
CREATE INDEX idx_same_as_same ON said_to_be_same_as(said_to_be_same_as);


-- FTS5 for full-text search
CREATE VIRTUAL TABLE entity_text_fts USING fts5(
    id UNINDEXED,
    label,
    description,
    content=entity_text,
    tokenize = 'unicode61 remove_diacritics 2',
    prefix = '2,3'
);