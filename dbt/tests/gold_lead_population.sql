{{ config(tags=['quality']) }}

-- Compare membership AND multiplicity. An ARN may legitimately occur in more
-- than one source table; Gold must preserve the eligible Silver population.
with expected as (
    select source_table, order_number, count(*) as row_count
    from {{ ref('silver_customer_lead_consolidated') }}
    where (mobile is null or mobile not in ('8527999655', '9999043353', '8448441792'))
      and (
          cast(dt_created_date as date) >= date_add(date_trunc('month', current_date()), interval -2 month)
          or cast(dt_update_date as date) >= date_add(date_trunc('month', current_date()), interval -2 month)
      )
    group by source_table, order_number
),
actual as (
    select lead_source_table as source_table, order_number, count(*) as row_count
    from {{ ref('gold_daily_operations_report') }}
    group by lead_source_table, order_number
)

select
    coalesce(e.source_table, a.source_table) as source_table,
    coalesce(e.order_number, a.order_number) as order_number,
    coalesce(e.row_count, 0) as expected_rows,
    coalesce(a.row_count, 0) as actual_rows
from expected e
full outer join actual a
    on e.source_table = a.source_table and e.order_number = a.order_number
where coalesce(e.row_count, 0) <> coalesce(a.row_count, 0)
