{{ config(
    materialized='table',
    keys=['user_id'],
    distributed_by=['user_id'],
    buckets=4
) }}

with latest as (
    select
        cast(after.UserID as varchar(50)) as user_id,
        cast(after.FirstName as varchar(500)) as first_name,
        cast(after.MiddleName as varchar(500)) as middle_name,
        cast(after.LastName as varchar(500)) as last_name,
        cast(after.ReportingTo as varchar(50)) as reporting_to,
        after.UserType as user_type,
        after.Active as active,
        after.InsertedDate as inserted_date,
        after.Updatedate as updated_date,
        cast(after.NVLoginId as varchar(100)) as login_id,
        after.BankAllocation as bank_allocation,
        cast(after.SelectedBanks as varchar(200)) as selected_banks,
        after.AgentType as agent_type,
        op as cdc_operation,
        source.ts_ms as source_ts_ms,
        ts_ms as debezium_ingested_ts_ms
    from ({{ current_cdc_rows(source('raw_iceberg', 'mbs_user_cdc_connect'), 'UserID') }}) cdc
)

select
    user_id,
    first_name,
    middle_name,
    last_name,
    nullif(trim(concat(
        coalesce(first_name, ''),
        ' ',
        coalesce(middle_name, ''),
        ' ',
        coalesce(last_name, '')
    )), '') as user_full_name,
    reporting_to,
    user_type,
    active,
    inserted_date,
    updated_date,
    login_id,
    bank_allocation,
    selected_banks,
    agent_type,
    cdc_operation,
    source_ts_ms,
    debezium_ingested_ts_ms
from latest
