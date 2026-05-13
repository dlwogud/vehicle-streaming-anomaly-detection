select 1
where not exists (
    select 1
    from {{ ref('stg_anomaly_data') }}
    where event_ts >= now() - interval '6 hours'
)
