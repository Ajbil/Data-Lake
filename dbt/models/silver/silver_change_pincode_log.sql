{{ config(
    materialized='table',
    keys=['id'],
    distributed_by=['id'],
    buckets=4
) }}

with raw_events as (
    select
        after.Id as id,
        after.Refnumber as ref_number,
        after.OldPicode as old_pincode,
        after.NewPicode as new_pincode,
        after.UpdateBy as updated_by,
        after.UpdateDate as updated_at,
        op as cdc_operation,
        source.ts_ms as source_ts_ms,
        ts_ms as debezium_ingested_ts_ms,
        row_number() over (
            partition by after.Id
            order by coalesce(source.ts_ms, ts_ms) desc, ts_ms desc
        ) as latest_rank
    from {{ source('raw_iceberg', 'change_pincode_log_cdc_connect') }}
    where op in ('r', 'c', 'u')
      and after is not null
)

select
    id,
    ref_number,
    old_pincode,
    new_pincode,
    updated_by,
    updated_at,
    cdc_operation,
    source_ts_ms,
    debezium_ingested_ts_ms
from raw_events
where latest_rank = 1
