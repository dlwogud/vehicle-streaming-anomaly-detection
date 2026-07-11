select
    md5(
        concat_ws(
            '||',
            vehicle_id,
            cast(window_start as text),
            anomaly_reason
        )
    )                                           as sustained_anomaly_key,
    vehicle_id,
    window_start,
    window_end,
    avg_engine_temp,
    max_rpm,
    avg_speed,
    event_count,
    anomaly_reason,
    case
        when anomaly_reason in (
            'SUSTAINED_HIGH_TEMP', 'SUSTAINED_HIGH_RPM'
        )                                       then 1
        when anomaly_reason = 'SUSTAINED_HIGH_LOAD' then 2
    end                                         as severity_level
from {{ ref('stg_window_anomaly_data') }}
where anomaly_reason != 'NORMAL_WINDOW'
