{{ config(
    materialized='table',
    distributed_by=['pincode'],
    buckets=4
) }}

with latest as (
    select
        after.ISeqNo as source_id,
        after.PinCode as pincode,
        after.State as state_name,
        after.District as district,
        after.IsServiceable as is_serviceable,
        after.IsMetro as is_metro,
        source.ts_ms as source_ts_ms,
        ts_ms as debezium_ingested_ts_ms,
        row_number() over (
            partition by after.ISeqNo
            order by coalesce(source.ts_ms, ts_ms) desc, ts_ms desc
        ) as latest_rank
    from {{ source('raw_iceberg', 'mas_pincode_cdc_connect') }}
    where op in ('r', 'c', 'u')
      and after is not null
)

select
    source_id,
    pincode,
    state_name,
    district,
    is_serviceable,
    is_metro,
    source_ts_ms,
    debezium_ingested_ts_ms
from latest
where latest_rank = 1
