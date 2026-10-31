{% macro current_cdc_rows(relation, primary_key) %}
{# One physical keyed source per relation. Raw keeps every event, including deletes. #}
select before, after, source, op, ts_ms
from (
    select
        before, after, source, op, ts_ms,
        row_number() over (
            partition by coalesce(after.{{ primary_key }}, before.{{ primary_key }})
            order by
                coalesce(lower(source.commit_lsn), lower(source.change_lsn), '') desc,
                case when op = 'r' and source.commit_lsn is not null then 1 else 0 end desc,
                coalesce(lower(source.change_lsn), '') desc,
                coalesce(source.event_serial_no, 0) desc,
                coalesce(source.ts_ms, ts_ms) desc,
                ts_ms desc
        ) as cdc_rank
    from {{ relation }}
    where op in ('r', 'c', 'u', 'd')
      and coalesce(after.{{ primary_key }}, before.{{ primary_key }}) is not null
) ranked
where cdc_rank = 1
  and op <> 'd'
{% endmacro %}
