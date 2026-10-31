{{ config(
    materialized='table',
    keys=['id'],
    distributed_by=['order_number'],
    buckets=4
) }}

with latest as (
    select
        after.Id as id,
        after.AgentId as agent_id,
        after.OrderNumber as order_number,
        after.AppointmentDateTime as appointment_date_time,
        after.DtCreatedDate as appointment_created_date,
        after.DtUpdatedDate as appointment_updated_date,
        after.status as status,
        after.SpecialCampaign as special_campaign,
        source.ts_ms as source_ts_ms,
        ts_ms as debezium_ingested_ts_ms
    from ({{ current_cdc_rows(source('raw_iceberg', 'mst_campaign_leads_cdc_connect'), 'Id') }}) cdc
)

select
    id,
    agent_id,
    order_number,
    appointment_date_time,
    appointment_created_date,
    appointment_updated_date,
    status,
    special_campaign,
    source_ts_ms,
    debezium_ingested_ts_ms
from latest
