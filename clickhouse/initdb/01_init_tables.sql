CREATE TABLE IF NOT EXISTS ais_db.position_reports (
    produced_at DateTime64(6) COMMENT 'Timestamp when message was produced to topic',
    consumed_at DateTime64(6) COMMENT 'Timestamp when message was consumed from topic',
    message_id UInt8 COMMENT 'ITU-R M.1371 message type (1, 2, or 3)',
    user_id String COMMENT 'MMSI — unique 9-digit vessel identifier',
    longitude Float64 COMMENT 'Longitude in degrees (East/West)',
    latitude Float64 COMMENT 'Latitude in degrees (North/South)',
    position_accuracy Bool COMMENT 'True = High (<10m, DGPS), False = Low (>10m, GPS)',
    raim Bool COMMENT 'True = RAIM in use, False = not in use',
    timestamp UInt8 COMMENT 'UTC second (0-59). 60=not available, 61=manual, 62=dead reckoning, 63=inoperative',
    cog Float32 COMMENT 'Course Over Ground in degrees (0-359.9). 360 = not available',
    sog Float32 COMMENT 'Speed Over Ground in knots (0-102.2). 102.3 = not available',
    true_heading UInt16 COMMENT 'Heading of the bow in degrees true north (0-359). 511 = not available',
    rate_of_turn Int16 COMMENT 'Rate of turn in degrees/min. +127=right, -127=left, -128=not available',
    navigational_status UInt8 COMMENT '0=under way, 1=at anchor, 2=not under command, 3=restricted, etc.',
    special_manoeuvre_indicator UInt8 COMMENT '0=not available, 1=not engaged, 2=engaged in special manoeuvre'
) ENGINE = ReplacingMergeTree(consumed_at)
PARTITION BY toYYYYMM(produced_at)
ORDER BY (user_id, produced_at)
TTL toDate(produced_at) + INTERVAL 1 YEAR;

CREATE TABLE IF NOT EXISTS ais_db.position_reports_kafka (
    produced_at DateTime64(6),
    message_id UInt8,
    user_id String,
    longitude Float64,
    latitude Float64,
    position_accuracy Bool,
    raim Bool,
    timestamp UInt8,
    cog Float32,
    sog Float32,
    true_heading UInt16,
    rate_of_turn Int16,
    navigational_status UInt8,
    special_manoeuvre_indicator UInt8
) ENGINE = Kafka('redpanda:29092', 'ais_data', 'clickhouse-consumer')
SETTINGS
    kafka_format = 'JSONEachRow',
    kafka_num_consumers = 1;

CREATE MATERIALIZED VIEW IF NOT EXISTS ais_db.position_reports_mv
TO ais_db.position_reports AS
SELECT
    produced_at,
    now64(6) AS consumed_at,
    message_id,
    user_id,
    longitude,
    latitude,
    position_accuracy,
    raim,
    timestamp,
    cog,
    sog,
    true_heading,
    rate_of_turn,
    navigational_status,
    special_manoeuvre_indicator
FROM ais_db.position_reports_kafka;
