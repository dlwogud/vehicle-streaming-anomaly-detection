select
    date_trunc('hour', event_ts)
    + floor(extract(minute from event_ts) / 5) * interval '5 minutes' as window_start,
    anomaly_reason,
    count(*) as anomaly_count,
    count(distinct vehicle_id) as affected_vehicle_count
from {{ ref('fct_vehicle_anomalies') }}
group by 1, 2
order by 1, 2
