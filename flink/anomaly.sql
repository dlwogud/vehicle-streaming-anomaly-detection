CREATE TABLE vehicle_source (
    vehicle_id STRING,
    `timestamp` STRING,
    speed DOUBLE,
    rpm INT,
    engine_temp DOUBLE,
    brake BOOLEAN,
    steering_angle DOUBLE
) WITH (
    'connector' = 'kafka',
    'topic' = 'vehicle-sensor-data',
    'properties.bootstrap.servers' = 'kafka:9092',
    'properties.group.id' = 'flink-anomaly-group-v2',
    'scan.startup.mode' = 'earliest-offset',
    'format' = 'json',
    'json.ignore-parse-errors' = 'true'
);

CREATE TABLE anomaly_sink (
    vehicle_id STRING,
    `timestamp` STRING,
    speed DOUBLE,
    rpm INT,
    engine_temp DOUBLE,
    brake BOOLEAN,
    steering_angle DOUBLE,
    anomaly_reason STRING
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://postgres:5432/vehicle_db',
    'table-name' = 'anomaly_data',
    'username' = 'flinkuser',
    'password' = 'flinkpw',
    'driver' = 'org.postgresql.Driver'
);

INSERT INTO anomaly_sink
SELECT
    vehicle_id,
    `timestamp`,
    speed,
    rpm,
    engine_temp,
    brake,
    steering_angle,
    CASE
        WHEN engine_temp > 90 THEN 'HIGH_ENGINE_TEMP'
        WHEN rpm > 4500 THEN 'HIGH_RPM'
        WHEN speed > 100 AND brake = TRUE THEN 'HIGH_SPEED_WITH_BRAKE'
        WHEN ABS(steering_angle) > 25 THEN 'SHARP_STEERING'
        ELSE 'NORMAL'
    END AS anomaly_reason
FROM vehicle_source;
