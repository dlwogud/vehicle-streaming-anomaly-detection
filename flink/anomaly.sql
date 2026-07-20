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

-- Event-level anomaly detection
-- Thresholds based on OBD-II standard PIDs and automotive engineering references:
--   engine_temp : ECT (PID 0x05) normal operating range 85-105°C; warning above 110°C
--   rpm         : typical gasoline redline ~6,500 RPM; flag sustained load above 85% (5,500 RPM)
--   speed+brake : emergency braking threshold set at 80 km/h (Korean road speed context)
--   steering    : parking maneuvers routinely exceed 25°; 45° flags genuine sharp steering at speed
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
        WHEN engine_temp > 110                   THEN 'HIGH_ENGINE_TEMP'
        WHEN rpm > 5500                          THEN 'HIGH_RPM'
        WHEN speed > 80 AND brake = TRUE         THEN 'HIGH_SPEED_WITH_BRAKE'
        WHEN ABS(steering_angle) > 45            THEN 'SHARP_STEERING'
        ELSE 'NORMAL'
    END AS anomaly_reason
FROM vehicle_source;

-- 30-second tumbling window: detect sustained abnormal conditions
-- Window thresholds are set tighter than event-level to catch patterns
-- that individual spikes might miss:
--   avg_engine_temp > 105°C : sustained operation above normal range upper bound
--   max_rpm > 5,000         : at least one high-load event within the window
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
        WHEN AVG(engine_temp) > 105 AND MAX(rpm) > 5000  THEN 'SUSTAINED_HIGH_LOAD'
        WHEN AVG(engine_temp) > 105                       THEN 'SUSTAINED_HIGH_TEMP'
        WHEN MAX(rpm) > 5000                              THEN 'SUSTAINED_HIGH_RPM'
        ELSE 'NORMAL_WINDOW'
    END AS anomaly_reason
FROM TABLE(
    TUMBLE(TABLE vehicle_source, DESCRIPTOR(event_ts), INTERVAL '30' SECOND)
)
GROUP BY vehicle_id, window_start, window_end;
