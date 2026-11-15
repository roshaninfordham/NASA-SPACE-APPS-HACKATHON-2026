CREATE EXTENSION IF NOT EXISTS timescaledb;
CREATE TABLE IF NOT EXISTS observations (
 checked_at timestamptz NOT NULL,
 nasa_file_updated_at timestamptz,
 source_url text NOT NULL,
 sha256 text NOT NULL CHECK (sha256 ~ '^[0-9a-f]{64}$'),
 status text NOT NULL CHECK (status IN ('available','stale')),
 PRIMARY KEY (checked_at, source_url)
);
SELECT create_hypertable('observations', by_range('checked_at'), if_not_exists => TRUE);
