# Airflow report failures and recovery

The existing `mbs_daily_operations_report` DAG runs every five minutes with one
active run at a time. Its single `run_dbt_daily_operations_report` task runs
`dbt run`, then `dbt test`. Inputs are Raw Iceberg and the dbt project; outputs are
the native Silver/Gold report tables. Source ingestion continues independently.

## What the logs mean

The task writes `[pipeline] START` and `[pipeline] SUCCESS` for `dbt_run` and
`dbt_test`. A command error writes, for example:

```text
[pipeline] FAILED stage=dbt_test exit_code=1; inspect the dbt output above.
```

The dbt lines immediately above identify the failed model/test, error or violating
row count, and compiled SQL path. Successful completion ends with
`[pipeline] SUCCESS all stages completed`. Build failure prevents tests from
running; test failure prevents this overall success message.

The shell preserves the failing exit code. The operator explicitly has zero
automatic retries and no skip exit codes: a nonzero exit fails the task and this
single-task DAG run. Airflow's existing ten-minute DAG timeout still bounds stuck
runs; a timeout/termination is reported by Airflow and may interrupt the shell
before it can print its stage summary.

## Inspect a failed run without the optional UI

From the project root, list recent runs and choose the failed run ID:

```powershell
$since = (Get-Date).ToUniversalTime().Date.ToString('yyyy-MM-dd')
docker exec mbs-airflow-scheduler airflow dags list-runs -d mbs_daily_operations_report --start-date $since --output table
```

Read its task log directly. Replace this example ID with the chosen run ID, and
use the appropriate attempt number if a task was manually cleared:

```powershell
$runId = 'scheduled__2026-10-31T18:20:00+00:00'
docker exec mbs-airflow-scheduler cat "/opt/airflow/logs/dag_id=mbs_daily_operations_report/run_id=$runId/task_id=run_dbt_daily_operations_report/attempt=1.log"
```

The optional UI at `http://localhost:8088` shows the same task log when started;
the CLI is the fallback when it is off. The `health:airflow` error also prints
the relevant task log directory. Do not publish whole logs without inspecting
them for source data or credentials.

## Recover safely

1. Record the run ID, failed stage, dbt model/test and error. For a data test,
   inspect the locally compiled SQL under `dbt/target/compiled/` to find violating
   rows; the printed path is inside `/opt/airflow/dbt` in the scheduler container.
2. Fix the cause: restore the unavailable dependency, correct SQL, or resolve the
   failing data/business rule. Use the existing connector/task checks if Raw
   ingestion is suspect. A dbt pass alone does not prove the input is fresh.
3. After any active report run finishes, let the next scheduled run rebuild and
   retest. To request a fresh scheduler-managed manual verification instead:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup.ps1 health:airflow
   ```

   That command unpauses the DAG and submits a new manual run. It respects
   `max_active_runs=1` but is not evidence of an automatic scheduled run.
4. Confirm the new run is `success`, the log reports nine successful models and
   32 passing tests, and both stage success messages appear. The earlier failure
   remains in history; do not mark it successful to hide the incident.

If you need to run dbt directly or edit derived data for diagnosis, pause the DAG,
wait for running/queued work to finish and restore its original pause state after
the work. Avoid simultaneous manual and scheduled rebuilds. Do not reset source
CDC offsets, delete Docker volumes or reseed data to recover a report failure.

## Scope and proof

Stage messages reuse the existing task rather than adding services, tasks or a
new monitoring stack. The permanent shell check can run in the existing runtime:

```powershell
docker cp infra/airflow/tests/check_dbt_command.py mbs-airflow-scheduler:/tmp/check_dbt_command.py
docker exec mbs-airflow-scheduler python /tmp/check_dbt_command.py /opt/airflow/dags/mbs_dbt_silver_gold.py
```

It checks stage ordering, suppression of tests after build failure, exit code
preservation, and absence of false success using controlled dbt shell functions.
It does not run real dbt. The [Step 5 note](../../notes/2026-11-01_airflow_failure_reporting.md)
records separate real dbt/Airflow failure probes and automatic scheduled-run proof.

Tables are rebuilt before quality tests. A failed test does **not** roll back or
hide those tables; a successful run is the evidence that both stages completed.
There is no atomic publication, freshness alerting or claim of production SLA.
