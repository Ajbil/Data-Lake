{{ config(
    materialized='table',
    keys=['source_table', 'customer_id'],
    distributed_by=['customer_id'],
    buckets=8
) }}

with original_pincode as (
    select ref_number, old_pincode as original_pincode
    from (
        select
            ref_number,
            old_pincode,
            row_number() over (
                partition by ref_number
                order by updated_at asc, id asc
            ) as rn
        from {{ ref('silver_change_pincode_log') }}
        where ref_number is not null
    ) p
    where rn = 1
),

customer_lead as (
    select
        'Customer_Lead' as source_table,
        after.CustomerId as customer_id,
        after.RefNumber as ref_number,
        after.RefNumber as order_number,
        cast(after.DESTINATION_CITY as varchar(500)) as destination_city,
        coalesce(pin.original_pincode, cast(after.PINCODE as varchar(50))) as base_pincode,
        cast(after.PINCODE as varchar(50)) as pincode_now,
        cast(after.STATE as varchar(100)) as state_from_lead,
        cast(after.MOBILE as varchar(50)) as mobile,
        cast(after.Bank_Status as varchar(200)) as bank_status,
        after.DTCreatedDate as dt_created_date,
        after.DTUpdateDate as dt_update_date,
        after.SR_Status as sr_status,
        cast(after.ChannelCode as varchar(100)) as channel_code,
        after.SourceSystem as source_system,
        after.BankId as bank_id,
        after.ClientName as client_name,
        cast(after.CustLandMark as varchar(500)) as cust_landmark,
        after.ServiceTypeID as service_type_id,
        after.Sub_Status as sub_status,
        1 as is_active_arn,
        op as cdc_operation,
        source.ts_ms as source_ts_ms,
        ts_ms as debezium_ingested_ts_ms
    from ({{ current_cdc_rows(source('raw_iceberg', 'customer_lead_cdc_connect'), 'CustomerId') }}) cdc
    left join original_pincode pin
        on after.RefNumber = pin.ref_number
),

customer_lead_icici as (
    select
        'Customer_Lead_ICICI' as source_table,
        after.CustomerId as customer_id,
        after.RefNumber as ref_number,
        after.RefNumber as order_number,
        cast(after.DESTINATION_CITY as varchar(500)) as destination_city,
        coalesce(pin.original_pincode, cast(after.PINCODE as varchar(50))) as base_pincode,
        cast(after.PINCODE as varchar(50)) as pincode_now,
        cast(after.STATE as varchar(100)) as state_from_lead,
        cast(after.MOBILE as varchar(50)) as mobile,
        cast(after.Bank_Status as varchar(200)) as bank_status,
        after.DTCreatedDate as dt_created_date,
        after.DTUpdateDate as dt_update_date,
        after.SR_Status as sr_status,
        cast(after.ChannelCode as varchar(100)) as channel_code,
        after.SourceSystem as source_system,
        after.BankId as bank_id,
        after.ClientName as client_name,
        cast(after.CustLandMark as varchar(500)) as cust_landmark,
        after.ServiceTypeID as service_type_id,
        after.Sub_Status as sub_status,
        1 as is_active_arn,
        op as cdc_operation,
        source.ts_ms as source_ts_ms,
        ts_ms as debezium_ingested_ts_ms
    from ({{ current_cdc_rows(source('raw_iceberg', 'customer_lead_icici_cdc_connect'), 'CustomerId') }}) cdc
    left join original_pincode pin
        on after.RefNumber = pin.ref_number
),

customer_lead_archived as (
    select
        'Customer_Lead_Archived' as source_table,
        after.CustomerId as customer_id,
        after.RefNumber as ref_number,
        after.RefNumber as order_number,
        cast(after.DESTINATION_CITY as varchar(500)) as destination_city,
        coalesce(pin.original_pincode, cast(after.PINCODE as varchar(50))) as base_pincode,
        cast(after.PINCODE as varchar(50)) as pincode_now,
        cast(after.STATE as varchar(100)) as state_from_lead,
        cast(after.MOBILE as varchar(50)) as mobile,
        cast(after.Bank_Status as varchar(200)) as bank_status,
        after.DTCreatedDate as dt_created_date,
        after.DTUpdateDate as dt_update_date,
        after.SR_Status as sr_status,
        cast(after.ChannelCode as varchar(100)) as channel_code,
        after.SourceSystem as source_system,
        after.BankId as bank_id,
        after.ClientName as client_name,
        cast(after.CustLandMark as varchar(500)) as cust_landmark,
        after.ServiceTypeID as service_type_id,
        after.Sub_Status as sub_status,
        0 as is_active_arn,
        op as cdc_operation,
        source.ts_ms as source_ts_ms,
        ts_ms as debezium_ingested_ts_ms
    from ({{ current_cdc_rows(source('raw_iceberg', 'customer_lead_archived_cdc_connect'), 'CustomerId') }}) cdc
    left join original_pincode pin
        on after.RefNumber = pin.ref_number
),

customer_lead_purge as (
    select
        'Customer_Lead_purge_details' as source_table,
        after.CustomerId as customer_id,
        after.RefNumber as ref_number,
        after.RefNumber as order_number,
        cast(after.DESTINATION_CITY as varchar(500)) as destination_city,
        coalesce(pin.original_pincode, cast(after.PINCODE as varchar(50))) as base_pincode,
        cast(after.PINCODE as varchar(50)) as pincode_now,
        cast(after.STATE as varchar(100)) as state_from_lead,
        cast(after.MOBILE as varchar(50)) as mobile,
        cast(after.Bank_Status as varchar(200)) as bank_status,
        after.DTCreatedDate as dt_created_date,
        after.DTUpdateDate as dt_update_date,
        after.SR_Status as sr_status,
        cast(after.ChannelCode as varchar(100)) as channel_code,
        after.SourceSystem as source_system,
        after.BankId as bank_id,
        after.ClientName as client_name,
        cast(after.CustLandMark as varchar(500)) as cust_landmark,
        after.ServiceTypeID as service_type_id,
        after.Sub_Status as sub_status,
        0 as is_active_arn,
        op as cdc_operation,
        source.ts_ms as source_ts_ms,
        ts_ms as debezium_ingested_ts_ms
    from ({{ current_cdc_rows(source('raw_iceberg', 'customer_lead_purge_details_cdc_connect'), 'CustomerId') }}) cdc
    left join original_pincode pin
        on after.RefNumber = pin.ref_number
)

select
    source_table,
    customer_id,
    ref_number,
    order_number,
    destination_city,
    base_pincode,
    pincode_now,
    state_from_lead,
    mobile,
    bank_status,
    dt_created_date,
    dt_update_date,
    sr_status,
    channel_code,
    source_system,
    bank_id,
    client_name,
    cust_landmark,
    service_type_id,
    sub_status,
    is_active_arn,
    cdc_operation,
    source_ts_ms,
    debezium_ingested_ts_ms
from customer_lead
union all
select
    source_table,
    customer_id,
    ref_number,
    order_number,
    destination_city,
    base_pincode,
    pincode_now,
    state_from_lead,
    mobile,
    bank_status,
    dt_created_date,
    dt_update_date,
    sr_status,
    channel_code,
    source_system,
    bank_id,
    client_name,
    cust_landmark,
    service_type_id,
    sub_status,
    is_active_arn,
    cdc_operation,
    source_ts_ms,
    debezium_ingested_ts_ms
from customer_lead_icici
union all
select
    source_table,
    customer_id,
    ref_number,
    order_number,
    destination_city,
    base_pincode,
    pincode_now,
    state_from_lead,
    mobile,
    bank_status,
    dt_created_date,
    dt_update_date,
    sr_status,
    channel_code,
    source_system,
    bank_id,
    client_name,
    cust_landmark,
    service_type_id,
    sub_status,
    is_active_arn,
    cdc_operation,
    source_ts_ms,
    debezium_ingested_ts_ms
from customer_lead_archived
union all
select
    source_table,
    customer_id,
    ref_number,
    order_number,
    destination_city,
    base_pincode,
    pincode_now,
    state_from_lead,
    mobile,
    bank_status,
    dt_created_date,
    dt_update_date,
    sr_status,
    channel_code,
    source_system,
    bank_id,
    client_name,
    cust_landmark,
    service_type_id,
    sub_status,
    is_active_arn,
    cdc_operation,
    source_ts_ms,
    debezium_ingested_ts_ms
from customer_lead_purge
