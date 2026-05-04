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
