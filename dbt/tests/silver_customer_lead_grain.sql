{{ config(tags=['quality']) }}

-- Customer IDs belong to a physical source table, not the whole union.
select source_table, customer_id, count(*) as row_count
from {{ ref('silver_customer_lead_consolidated') }}
group by source_table, customer_id
having count(*) > 1
