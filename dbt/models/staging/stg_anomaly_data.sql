select
    vehicle_id,
    cast("timestamp" as timestamp) as event_ts,
    speed,
    rpm,
    engine_temp,
    brake,
    steering_angle,
    anomaly_reason,
    date_trunc('day', cast("timestamp" as timestamp)) as event_date
from {{ source('vehicle_raw', 'anomaly_data') }}
