with ranked_events as (
    select
        md5(
            concat_ws(
                '||',
                vehicle_id,
                cast(event_ts as text),
                anomaly_reason
            )
        ) as anomaly_event_key,
        vehicle_id,
        event_ts,
        event_date,
        speed,
        rpm,
        engine_temp,
        brake,
        steering_angle,
        anomaly_reason,
        row_number() over (
            partition by vehicle_id, event_ts, anomaly_reason
            order by event_ts desc
        ) as event_rank
    from {{ ref('stg_anomaly_data') }}
)

select
    anomaly_event_key,
    vehicle_id,
    event_ts,
    event_date,
    speed,
    rpm,
    engine_temp,
    brake,
    steering_angle,
    anomaly_reason,
    case
        when anomaly_reason = 'NORMAL' then 0
        when anomaly_reason in ('HIGH_ENGINE_TEMP', 'HIGH_RPM') then 1
        else 2
    end as severity_level
from ranked_events
where event_rank = 1
