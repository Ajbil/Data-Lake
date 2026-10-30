{{ config(
    materialized='table',
    distributed_by=['order_number'],
    buckets=8
) }}

with combined as (
    select
        'ServiceRequestAssignLog' as source_table,
        cast(null as bigint) as source_id,
        after.ORDER_NUMBER as order_number,
        after.UserID as user_id,
        after.StatusID as status_id,
        after.UpdateStatusDate as update_status_date,
        after.Active as active,
        after.agentid as agent_id,
        op as cdc_operation,
        source.ts_ms as source_ts_ms,
        ts_ms as debezium_ingested_ts_ms
    from {{ source('raw_iceberg', 'service_request_assign_log_cdc_connect') }}
    where op in ('r', 'c', 'u')
      and after is not null

    union all

    select
        'ServiceRequestAssignLog_archieved' as source_table,
        after.Id as source_id,
        after.ORDER_NUMBER as order_number,
        after.UserID as user_id,
        after.StatusID as status_id,
        after.UpdateStatusDate as update_status_date,
        after.Active as active,
        after.AgentId as agent_id,
        op as cdc_operation,
        source.ts_ms as source_ts_ms,
        ts_ms as debezium_ingested_ts_ms
    from {{ source('raw_iceberg', 'service_request_assign_log_archieved_cdc_connect') }}
    where op in ('r', 'c', 'u')
      and after is not null

    union all

    select
        'ServiceRequestAssignLog_purge_details' as source_table,
        after.Id as source_id,
        after.ORDER_NUMBER as order_number,
        after.UserID as user_id,
        after.StatusID as status_id,
        after.UpdateStatusDate as update_status_date,
        after.Active as active,
        after.AgentId as agent_id,
        op as cdc_operation,
        source.ts_ms as source_ts_ms,
        ts_ms as debezium_ingested_ts_ms
    from {{ source('raw_iceberg', 'service_request_assign_log_purge_details_cdc_connect') }}
    where op in ('r', 'c', 'u')
      and after is not null
)

select *
from combined
