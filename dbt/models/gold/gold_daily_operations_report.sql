{{ config(
    materialized='table',
    distributed_by=['order_number'],
    buckets=8
) }}

with date_window as (
    select date_add(date_trunc('month', current_date()), interval -2 month) as window_start
),

serviceable_pincode as (
    select distinct pincode
    from {{ ref('silver_pincode_serviceability') }}
    where is_serviceable = 1
),

status_events as (
    select
        order_number,
        user_id as status_user_id,
        status_id as status_status_id,
        log_date as status_log_date,
        agent_id as status_agent_id,
        supervisor as status_supervisor_name,
        coordinator,
        customer_available_pincode,
        sub_status as status_sub_status
    from (
        select
            order_number,
            user_id,
            status_id,
            log_date,
            agent_id,
            supervisor,
            coordinator,
            customer_available_pincode,
            sub_status,
            row_number() over (
                partition by order_number
                order by log_date desc, coalesce(source_ts_ms, debezium_ingested_ts_ms) desc, debezium_ingested_ts_ms desc
            ) as rn
        from {{ ref('silver_sr_status_update_log_consolidated') }}
        where status_id = 1
          and order_number is not null
    ) latest_status
    where rn = 1
),

campaign_leads as (
    select
        order_number,
        agent_id as campaign_agent_id,
        appointment_date_time,
        appointment_created_date,
        appointment_updated_date,
        status as campaign_status,
        special_campaign
    from (
        select
            order_number,
            agent_id,
            appointment_date_time,
            appointment_created_date,
            appointment_updated_date,
            status,
            special_campaign,
            row_number() over (
                partition by order_number
                order by appointment_created_date desc, coalesce(source_ts_ms, debezium_ingested_ts_ms) desc, debezium_ingested_ts_ms desc
            ) as rn
        from {{ ref('silver_campaign_leads') }}
        where order_number is not null
    ) latest_campaign
    where rn = 1
),

assigned_agents as (
    select
        order_number,
        user_id as assignment_user_id,
        status_id as assignment_status_id,
        update_status_date as assignment_update_status_date,
        active as assignment_active,
        agent_id as assignment_agent_id
    from (
        select
            order_number,
            user_id,
            status_id,
            update_status_date,
            active,
            agent_id,
            row_number() over (
                partition by order_number
                order by update_status_date desc, coalesce(source_ts_ms, debezium_ingested_ts_ms) desc, debezium_ingested_ts_ms desc
            ) as rn
        from {{ ref('silver_service_request_assign_log_consolidated') }}
        where order_number is not null
    ) latest_assignment
    where rn = 1
)

select
    vcl.order_number,
    vcl.destination_city,
    vcl.bank_status,
    vcl.base_pincode,
    vcl.pincode_now as pincode,
    pp.state_name as state,
    vcl.dt_created_date,
    vcl.dt_update_date,
    vcl.sr_status,
    vcl.channel_code,
    vcl.source_system,
    vcl.bank_id,
    vcl.client_name,
    vcl.cust_landmark,
    coalesce(sra.assignment_agent_id, mcl.campaign_agent_id, srlog.status_agent_id) as agent_id,
    sra.assignment_agent_id,
    sra.assignment_user_id,
    sra.assignment_status_id,
    sra.assignment_update_status_date,
    sra.assignment_active,
    srlog.status_user_id,
    srlog.status_status_id,
    srlog.status_log_date,
    srlog.status_agent_id,
    srlog.status_sub_status,
    srlog.coordinator,
    srlog.customer_available_pincode,
    mcl.campaign_agent_id,
    mcl.campaign_status,
    mcl.special_campaign,
    agent_user.user_id as agent_user_id,
    agent_user.login_id as agent_login_id,
    coalesce(agent_user.user_full_name, agent_user.login_id, coalesce(sra.assignment_agent_id, mcl.campaign_agent_id, srlog.status_agent_id)) as agent_name,
    concat(
        coalesce(sra.assignment_agent_id, mcl.campaign_agent_id, srlog.status_agent_id),
        ' - ',
        coalesce(agent_user.user_full_name, agent_user.login_id, coalesce(sra.assignment_agent_id, mcl.campaign_agent_id, srlog.status_agent_id))
    ) as agent_id_name,
    agent_user.reporting_to as supervisor_user_id,
    coalesce(supervisor_user.user_full_name, supervisor_user.login_id, srlog.status_supervisor_name) as supervisor_name,
    agent_user.user_type as agent_user_type,
    agent_user.active as agent_active,
    agent_user.agent_type,
    case
        when mp.pincode is not null then 'Serviceable'
        else 'Non-Serviceable'
    end as serviceable_pincode,
    case
        when srlog.order_number is not null then 'RPush'
        else 'Fresh'
    end as record_type,
    case
        when mcl.order_number is not null then 'High-priority'
        else 'Non-priority'
    end as champaines,
    mcl.appointment_date_time,
    mcl.appointment_created_date,
    vcl.is_active_arn,
    vcl.source_table as lead_source_table,
    vcl.source_ts_ms as lead_source_ts_ms,
    vcl.debezium_ingested_ts_ms as lead_debezium_ingested_ts_ms
from {{ ref('silver_customer_lead_consolidated') }} vcl
cross join date_window dw
left join {{ ref('silver_pincode_state_lookup') }} pp
    on pp.pincode = vcl.pincode_now
left join assigned_agents sra
    on vcl.ref_number = sra.order_number
left join serviceable_pincode mp
    on vcl.base_pincode = mp.pincode
left join status_events srlog
    on vcl.ref_number = srlog.order_number
left join campaign_leads mcl
    on vcl.ref_number = mcl.order_number
left join {{ ref('silver_mbs_user') }} agent_user
    on coalesce(sra.assignment_agent_id, mcl.campaign_agent_id, srlog.status_agent_id) = agent_user.user_id
left join {{ ref('silver_mbs_user') }} supervisor_user
    on agent_user.reporting_to = supervisor_user.user_id
where (vcl.mobile is null or vcl.mobile not in ('8527999655', '9999043353', '8448441792'))
  and (
      cast(vcl.dt_created_date as date) >= dw.window_start
      or cast(vcl.dt_update_date as date) >= dw.window_start
  )
