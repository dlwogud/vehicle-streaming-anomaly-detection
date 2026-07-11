select
    vehicle_id,
    window_start,
    window_end,
    avg_engine_temp,
    max_rpm,
    avg_speed,
    event_count,
    anomaly_reason
from {{ source('vehicle_raw', 'window_anomaly_data') }}
