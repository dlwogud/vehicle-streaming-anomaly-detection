CREATE TABLE IF NOT EXISTS anomaly_data (
    vehicle_id TEXT,
    "timestamp" TEXT,
    speed DOUBLE PRECISION,
    rpm INTEGER,
    engine_temp DOUBLE PRECISION,
    brake BOOLEAN,
    steering_angle DOUBLE PRECISION,
    anomaly_reason TEXT
);

CREATE INDEX IF NOT EXISTS idx_anomaly_data_vehicle_timestamp
    ON anomaly_data (vehicle_id, "timestamp");

CREATE TABLE IF NOT EXISTS window_anomaly_data (
    vehicle_id       TEXT,
    window_start     TIMESTAMP,
    window_end       TIMESTAMP,
    avg_engine_temp  DOUBLE PRECISION,
    max_rpm          INTEGER,
    avg_speed        DOUBLE PRECISION,
    event_count      BIGINT,
    anomaly_reason   TEXT
);

CREATE INDEX IF NOT EXISTS idx_window_anomaly_vehicle_window
    ON window_anomaly_data (vehicle_id, window_start);
