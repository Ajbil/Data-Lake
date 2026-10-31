# Step 4: targeted dbt quality checks

## Scope and decision

Started from merged PR #3 (`main` at `d08628b`) on
`codex/add-dbt-quality-checks`. Reuse dbt because it already tests the report after
each scheduled rebuild. Inputs are the native Silver lead/user tables and Gold
report; the existing Airflow task depends on their tests returning success.
No new packages, services, ports, source mutations, or model transformations.
The [runbook](../docs/runbooks/02_poc_execution.md#targeted-report-quality-checks)
explains operation and failure handling. If a check blocks progress, inspect its
failing keys and resolve data or clarify the business contract; disabling it is
not the fallback.

## Inspection and contracts

- Silver lead grain is `(source_table, customer_id)`. StarRocks `DUPLICATE KEY`
  defines sort keys here and does not enforce uniqueness. The new singular test
  detects duplicate physical entities; it allows cross-source key reuse.
- Gold currently does not expose `customer_id`. Compare grouped row counts by
  source table and order number against date/mobile-eligible Silver instead of
  asserting global ARN uniqueness. This detects membership/multiplicity drift,
  including fanout, without conflating separate active/archive records.
- Gold's optional `agent_id` has a dbt relationship to the user master. Generic
  relationships ignore null child keys, allowing unassigned leads.
- Existing accepted-value tests alone allow nulls. Three new not-null tests close
  this gap for serviceability, Fresh/RPush and priority labels. Together they
  enforce exhaustive report categories without a redundant category sum test.
- All six additions are tagged `quality` and use default error severity. The
  project grows from 26 to 32 tests, with the existing nine models unchanged.

Initial profiling found 19 Silver leads (16 active and
one in each other source table), 11 Gold rows, no duplicate physical keys, no
Gold source/reference mismatches and no unresolved non-null Gold agents. All 11
Gold rows were serviceable and assigned; the isolated positive fixture exercises
the otherwise absent non-serviceable/unassigned cases.

## Validation procedure

1. The report DAG was initially unpaused. Pause it and wait until no queued or
   running runs remain; never cancel a run or run overlapping dbt commands.
2. Run `dbt test --select tag:quality` on `analytics`.
3. Generate a separate `quality_step4_<8 hex digits>` schema. For each of
   `silver_customer_lead_consolidated`, `silver_mbs_user` and
   `gold_daily_operations_report`, execute `CREATE TABLE <fixture>.<table> LIKE
   analytics.<table>` and `INSERT INTO <fixture>.<table> SELECT * FROM
   analytics.<table>`.
4. Apply the committed `valid-fixture.sql` after replacing its recorded schema
   name with the newly generated name. It adds the same synthetic ID/reference in
   active and archived Silver sources, matching Gold rows, both serviceability
   labels and null agents. Execute the same six real tests, setting container env
   `STARROCKS_SCHEMA=<fixture>`; require six passes.
5. Apply `invalid-fixture.sql` only to that isolated schema. It adds a repeated
   physical lead and a Gold row with an unknown agent and three null labels.
   Require dbt exit 1 and six **data failures**, with no SQL/runtime errors.
6. Run a full `dbt build` on `analytics` and require all nine models and 32 tests.
7. In cleanup, drop only the generated schema and restore the DAG's original
   pause state. Confirm no fixture schemas remain and the working report is
   intact. The validation driver lives under ignored `.runtime/quality-step4/`;
   logs and selected fixture SQL are curated into the evidence directory.

All dbt calls use the scheduler container runtime documented in the runbook; only
the isolated calls add `-e STARROCKS_SCHEMA=<fixture>` before the container name.
The temporary schema is local to StarRocks, not an alternate source/Raw catalog.

## Results

Execution evidence is in
[`evidence/quality-2026-10-31/`](../evidence/quality-2026-10-31/).

| Run/check | Observed result |
| --- | --- |
| Working report, new tests only | 6 passes, exit 0 |
| Isolated valid fixture | 6 passes, exit 0; cross-source repeated ID/ARN and null agents allowed |
| Isolated invalid fixture | 6 data failures, exit 1; no SQL/runtime errors |
| Population failure detail | Two mismatched groups: Silver duplicate increases expected count; orphan Gold row has no Silver parent |
| Full working build | 9 models and 32 tests pass, exit 0; no warnings/skips |
| Cleanup | `quality_step4_742501b1` removed; zero fixture schemas and zero fixture Gold rows in analytics |
| Final report | 19 Silver leads and 11 Gold rows |
| Operational state | All 16 required connector tasks RUNNING; DAG restored to its original unpaused state |

`results.csv` preserves each executed resource's status/failure count. The valid
and invalid fixture logs are actual dbt output, not simulated expectations.
`full-build-summary.txt` records the complete build's final status. Only derived
tables in the generated schema received deliberate bad data; source and Raw
tables were never modified.

## Limits and gotchas

- Full rebuilds remain. Quality failure does not atomically roll back publication.
- These are bounded integrity checks, not source-to-Raw reconciliation, freshness
  monitoring, semantic deduplication across sources or proof of readable PII.
- Active assignment-log updates/deletes still lack a stable source key; Step 4
  does not extend the CDC guarantee for that branch.
- Local mysql invocation needs quoted `--host=127.0.0.1` in PowerShell. The first
  unquoted short-host invocation was parsed as host `127` and failed to connect;
  no data or schedule change occurred in that attempt.
