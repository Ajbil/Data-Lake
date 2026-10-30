{{ config(
    materialized='table',
    keys=['source_table', 'log_id'],
    distributed_by=['order_number'],
    buckets=8
) }}

with combined as (
    select
        'SRStatusUpdateLog' as source_table,
        after.LogId as log_id,
        after.ORDER_NUMBER as order_number,
        after.UserID as user_id,
        after.StatusID as status_id,
        after.LogDate as log_date,
        after.AgentId as agent_id,
        after.Supervisor as supervisor,
        after.Coordinator as coordinator,
        after.CustomerAvailablePincode as customer_available_pincode,
        after.SubStatus as sub_status,
        op as cdc_operation,
        source.ts_ms as source_ts_ms,
        ts_ms as debezium_ingested_ts_ms,
        row_number() over (
            partition by after.LogId
            order by coalesce(source.ts_ms, ts_ms) desc, ts_ms desc
        ) as latest_rank
    from {{ source('raw_iceberg', 'sr_status_update_log_cdc_connect') }}
    where op in ('r', 'c', 'u')
      and after is not null

    union all

    select
        'SRStatusUpdateLog_archieved' as source_table,
        after.LogId as log_id,
        after.ORDER_NUMBER as order_number,
        after.UserID as user_id,
        after.StatusID as status_id,
        after.LogDate as log_date,
        after.AgentId as agent_id,
        after.Supervisor as supervisor,
        after.Coordinator as coordinator,
        after.CustomerAvailablePincode as customer_available_pincode,
        after.SubStatus as sub_status,
        op as cdc_operation,
        source.ts_ms as source_ts_ms,
        ts_ms as debezium_ingested_ts_ms,
        row_number() over (
            partition by after.LogId
            order by coalesce(source.ts_ms, ts_ms) desc, ts_ms desc
        ) as latest_rank
    from {{ source('raw_iceberg', 'sr_status_update_log_archieved_cdc_connect') }}
    where op in ('r', 'c', 'u')
      and after is not null

    union all

    select
        'SRStatusUpdateLog_purge_details' as source_table,
        after.LogId as log_id,
        after.ORDER_NUMBER as order_number,
        after.UserID as user_id,
        after.StatusID as status_id,
        after.LogDate as log_date,
        after.AgentId as agent_id,
        after.Supervisor as supervisor,
        after.Coordinator as coordinator,
        after.CustomerAvailablePincode as customer_available_pincode,
        after.SubStatus as sub_status,
        op as cdc_operation,
        source.ts_ms as source_ts_ms,
        ts_ms as debezium_ingested_ts_ms,
        row_number() over (
            partition by after.LogId
            order by coalesce(source.ts_ms, ts_ms) desc, ts_ms desc
        ) as latest_rank
    from {{ source('raw_iceberg', 'sr_status_update_log_purge_details_cdc_connect') }}
    where op in ('r', 'c', 'u')
      and after is not null
)

select
    source_table,
    log_id,
    order_number,
    user_id,
    status_id,
    log_date,
    agent_id,
    supervisor,
    coordinator,
    customer_available_pincode,
    sub_status,
    cdc_operation,
    source_ts_ms,
    debezium_ingested_ts_ms
from combined
where latest_rank = 1
