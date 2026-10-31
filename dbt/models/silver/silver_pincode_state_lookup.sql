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
        source.ts_ms as source_ts_ms,
        ts_ms as debezium_ingested_ts_ms
    from ({{ current_cdc_rows(source('raw_iceberg', 'mas_pincode_for_mis_hdfc_cdc_connect'), 'ISeqNo') }}) cdc
)

select
    source_id,
    pincode,
    state_name,
    district,
    source_ts_ms,
    debezium_ingested_ts_ms
from latest
