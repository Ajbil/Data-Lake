-- Target-engine fixtures for the same macro used by the Silver models.
-- id, operation, commit position, change position, serial, source ms, arrival ms, value
{% set events = [
    (1, 'c', 1, 1, 1, 100, 100, 'deleted'),
    (1, 'd', 2, 1, 1, 200, 200, 'deleted'),
    (2, 'c', 1, 1, 1, 900, 900, 'older-source'),
    (2, 'u', 2, 1, 1, 100, 100, 'newer-source'),
    (3, 'c', 1, 1, 1, 900, 900, 'older-than-snapshot'),
    (3, 'r', 3, 0, 0, 100, 100, 'snapshot'),
    (4, 'c', 4, 1, 1, 100, 900, 'older-serial'),
    (4, 'u', 4, 1, 2, 100, 100, 'newer-serial'),
    (5, 'c', 5, 1, 1, 100, 900, 'older-change'),
    (5, 'u', 5, 2, 1, 100, 100, 'newer-change'),
    (6, 'c', 6, 1, 1, 100, 100, 'replayed'),
    (6, 'c', 6, 1, 1, 100, 900, 'replayed'),
    (7, 'c', 7, 1, 1, 100, 100, 'first-life'),
    (7, 'd', 8, 1, 1, 200, 200, 'first-life'),
    (7, 'c', 9, 1, 1, 300, 300, 'recreated'),
    (8, 'r', 10, 0, 0, 100, 100, 'snapshot-at-boundary'),
    (8, 'u', 10, 2, 1, 900, 900, 'pre-snapshot-change'),
    (9, 'r', 0, 0, 0, 100, 100, 'fallback-old'),
    (9, 'u', 0, 0, 0, 200, 200, 'fallback-new'),
    (none, 'c', 11, 1, 1, 100, 100, 'invalid-key')
] %}
{% set expected = [
    (2, 'newer-source'), (3, 'snapshot'), (4, 'newer-serial'),
    (5, 'newer-change'), (6, 'replayed'), (7, 'recreated'),
    (8, 'snapshot-at-boundary'), (9, 'fallback-new')
] %}

with event_values as (
    {% for id, op, commit, change, serial, source_ms, arrival_ms, value in events %}
    select {{ id if id is not none else 'cast(null as int)' }} as id,
           '{{ op }}' as op,
           {% if commit %}'00000000:{{ '%08x' | format(commit) }}:0001'{% else %}cast(null as varchar){% endif %} as commit_lsn,
           {% if change %}'00000000:{{ '%08x' | format(change) }}:0001'{% else %}cast(null as varchar){% endif %} as change_lsn,
           {% if serial %}{{ serial }}{% else %}cast(null as bigint){% endif %} as event_serial_no,
           {{ source_ms }} as source_ms, {{ arrival_ms }} as arrival_ms,
           '{{ value }}' as value
    {% if not loop.last %}union all{% endif %}
    {% endfor %}
), raw_events as (
    select
        case when op = 'd' then named_struct('Id', id, 'value', value) end as before,
        case when op <> 'd' then named_struct('Id', id, 'value', value) end as after,
        named_struct('commit_lsn', commit_lsn, 'change_lsn', change_lsn,
                     'event_serial_no', event_serial_no, 'ts_ms', source_ms) as source,
        op, arrival_ms as ts_ms
    from event_values
), actual as (
    select after.Id as id, after.value as value
    from ({{ current_cdc_rows('raw_events', 'Id') }}) current_rows
), expected as (
    {% for id, value in expected %}
    select {{ id }} as id, '{{ value }}' as value
    {% if not loop.last %}union all{% endif %}
    {% endfor %}
)
select expected.id as expected_id, actual.id as actual_id,
       expected.value as expected_value, actual.value as actual_value
from expected
full outer join actual on expected.id = actual.id
where expected.id is null or actual.id is null or not (expected.value <=> actual.value)
union all
select cast(null as int), id, 'exactly one current row', cast(count(*) as varchar)
from actual
group by id
having count(*) <> 1
