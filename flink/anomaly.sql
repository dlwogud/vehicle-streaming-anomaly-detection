CREATE TABLE vehicle_source (
    vehicle_id STRING,
    `timestamp` STRING,
    speed DOUBLE,
    rpm INT,
    engine_temp DOUBLE,
    brake BOOLEAN,
    steering_angle DOUBLE,
    event_ts AS TO_TIMESTAMP(REPLACE(`timestamp`, 'T', ' ')),
    WATERMARK FOR event_ts AS event_ts - INTERVAL '5' SECOND
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

CREATE TABLE window_anomaly_sink (
    vehicle_id      STRING,
    window_start    TIMESTAMP(3),
    window_end      TIMESTAMP(3),
    avg_engine_temp DOUBLE,
    max_rpm         INT,
    avg_speed       DOUBLE,
    event_count     BIGINT,
    anomaly_reason  STRING
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://postgres:5432/vehicle_db',
    'table-name' = 'window_anomaly_data',
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

INSERT INTO window_anomaly_sink
SELECT
    vehicle_id,
    window_start,
    window_end,
    ROUND(AVG(engine_temp), 2)   AS avg_engine_temp,
    MAX(rpm)                      AS max_rpm,
    ROUND(AVG(speed), 2)          AS avg_speed,
    COUNT(*)                      AS event_count,
    CASE
        WHEN AVG(engine_temp) > 85 AND MAX(rpm) > 4000 THEN 'SUSTAINED_HIGH_LOAD'
        WHEN AVG(engine_temp) > 85                     THEN 'SUSTAINED_HIGH_TEMP'
        WHEN MAX(rpm) > 4000                           THEN 'SUSTAINED_HIGH_RPM'
        ELSE 'NORMAL_WINDOW'
    END AS anomaly_reason
FROM TABLE(
    TUMBLE(TABLE vehicle_source, DESCRIPTOR(event_ts), INTERVAL '30' SECOND)
)
GROUP BY vehicle_id, window_start, window_end;
