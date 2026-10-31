# Step 5: clear report failures and scheduled execution

## Scope and inspection

Started from merged PR #4 (`main` at `258f026`) on
`codex/clarify-airflow-failures`. Work began on October 31 and evidence/recovery
documentation was completed on November 1 (Asia/Calcutta); recorded task logs
use UTC. The existing `set -euo pipefail` already stops
on dbt errors, and recent scheduled runs already succeed. This step makes failure
reporting explicit rather than claiming to fix a previously swallowed dbt error.

Keep the existing single task and ID, five-minute schedule, one active run and
ten-minute DAG timeout. Add stage start/success/error summaries, preserve the
failed command's status, and explicitly configure no automatic retries and no
skip exit codes. The installed Airflow 2.10.5 BashOperator otherwise treats exit
99 as skipped. Its installed `operators/bash.py` confirms nonzero exits outside
the skip list raise an Airflow exception.

Raw feeds dbt, Silver/Gold feed the report, and the Airflow run depends on both
model and test success. Reusing the task keeps this a small local POC change.
The fallback on failure is inspecting the named error and fixing/rerunning via
the [recovery runbook](../docs/runbooks/03_airflow_failures.md), not retrying blindly
or marking a run successful. No new service, dependency, port or data model.

## Verification method

- The permanent standard-library shell check extracts `DBT_COMMAND` from the DAG
  without importing Airflow. Only its working directory is relocated. Controlled
  shell functions exercise success, build exit 17, test exit 1 and test exit 99.
- Two temporary dbt projects use the real installed adapter and task contract.
  Their command/profile paths point to `/tmp/step5_<token>/<case>` and output
  schemas are `step5_build_<token>` / `step5_quality_<token>`.
- The build probe selects a nonexistent column; tests must never start. The
  quality probe builds a one-row model with null `id`, then fails its actual dbt
  `not_null` test. Temporary unscheduled DAGs use the production operator's shell,
  environment and failure settings; `DAG.test()` records both task and DAG states.
  These are isolated failure probes, not automatic scheduled-run evidence.
- The real report remains unpaused during these isolated probes. A normal
  scheduler-created run must separately show `run_type=scheduled`, task/run
  success, nine model successes, 32 test passes and the new stage summaries.
- Temporary project files and derived schemas are removed after collecting
  evidence. No failure fixture is inserted into SQL Server, Raw or analytics.

## Results

Execution results and curated logs are recorded in
[`evidence/airflow-2026-11-01/`](../evidence/airflow-2026-11-01/).

| Check | Observed result |
| --- | --- |
| Shell regression | Four cases pass: success, build exit 17, test exit 1, test exit 99 |
| Real build failure | `step5_build_failure_3089eea5`: task and DAG failed; `dbt_run` exit 1; no test stage started |
| Real quality failure | `step5_quality_failure_3089eea5`: build passed; `not_null_probe_entity_id` returned one violating row; task and DAG failed, `dbt_test` exit 1 |
| Automatic scheduled run | `scheduled__2026-10-31T18:20:00+00:00`: `run_type=scheduled`, `external_trigger=false`, task and DAG success, first attempt |
| Scheduled dbt output | Nine model successes and 32 test passes, no warnings/skips; both stage and overall success messages |
| Cleanup/health | Zero probe schemas or registered probe DAGs; 11 Gold rows; no DAG import errors; 16 connector tasks RUNNING; report remains unpaused |

The scheduled run actually started at 18:25:00.518889 UTC and ended at
18:26:57.869940 UTC (23:55:00 to 23:56:57 IST on October 31), about 117 seconds.
Its run ID identifies the data interval, not the wall-clock task start. This is
one observed successful run, not a freshness/SLA benchmark. No report run was
manually triggered or paused for this verification.

The temporary probe DAGs were instantiated only by the local validation process,
outside the scheduler's DAG folder. Their failed task/run records remain as
test history; they are not registered/scheduled DAGs. Their generated schemas
and projects were removed. The local validation driver remains under ignored
`.runtime/airflow-step5/` for inspection; curated logs exclude duplicated console
handlers, command/environment dumps and terminal color escapes.

## Limits

No alert delivery, automatic recovery or atomic publication was added. Gold is
rebuilt before tests; failed quality tests do not roll back an already rebuilt
table. The actual dbt test output still supplies the detailed failing test and
row count; the new summary supplies its stage and exit code. Abrupt termination
may prevent a shell summary; Airflow's task/DAG state remains authoritative.
