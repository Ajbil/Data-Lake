# Evidence index

These are dated observations from the local synthetic report pipeline. Read
them with the [current README](../README.md), [limitations](../project_risks.md)
and linked notes. Stored results do not imply a currently running service or a
permanent row count. Original measurement files remain in their existing folders.

## 1. Working baseline

[Note](../notes/2026-10-31_working_baseline.md) ·
[39 count comparisons](baseline-2026-10-31/count-deltas.csv) ·
[connector states before](baseline-2026-10-31/connector-status-before.csv) /
[after](baseline-2026-10-31/connector-status-after.csv) ·
[timing](baseline-2026-10-31/latency.csv).

The source task was running while all fifteen required sink tasks had failed.
Targeted task restarts recovered this observed run; they were not a permanent
root-cause fix. A retained synthetic insert increased Gold from 10 to 11 rows.
Kafka/Raw/Gold were observed after 57.223 / 63.185 / 233.259 seconds from command
start. Polling gaps and a queued manual trigger prevent treating this as an
automatic-schedule latency SLA. That baseline had 25 dbt tests.

## 2. Keyed CDC correctness

[Note](../notes/2026-10-31_cdc_correctness.md) ·
[stale delete before](cdc-correctness-2026-10-31/stale-delete-before.tsv) ·
[old-rule fixture failures](cdc-correctness-2026-10-31/fixture-before.txt) ·
[full corrected build](cdc-correctness-2026-10-31/build-and-tests.txt) ·
[final delete assertion](cdc-correctness-2026-10-31/delete-final.txt).

The old rule left a deleted lead current and failed six controlled cases. The
source-position-aware rule passed nine models and 26 tests, plus the live tagged
delete/recreate/update checks. Its stable-key/LSN assumptions and keyless active
assignment exception are explicit; this is not a blanket exactly-once claim.

## 3. End-to-end smoke check

[Note](../notes/2026-10-31_cdc_smoke_check.md) ·
[successful lifecycle](cdc-smoke-2026-10-31/positive-summary.json) ·
[checkpoints](cdc-smoke-2026-10-31/positive-checkpoints.csv) ·
[intentional-failure cleanup](cdc-smoke-2026-10-31/expected-failure-summary.json).

Insert, update, delete and another rebuild passed, with owned source-row cleanup
and original pause-state restoration. Total elapsed time was 700.281 seconds,
including 259 seconds waiting for an active scheduled run. The intentional
failure exited 1 while cleanup succeeded (100.027 seconds). These controlled
rebuilds are lifecycle evidence, not normal-schedule latency measurements.

## 4. Targeted quality checks

[Note](../notes/2026-10-31_targeted_quality_checks.md) ·
[valid fixture](quality-2026-10-31/valid-fixture.txt) ·
[invalid fixture](quality-2026-10-31/invalid-fixture.txt) ·
[resource results](quality-2026-10-31/results.csv) ·
[complete build summary](quality-2026-10-31/full-build-summary.txt).

All six added tests passed valid data (including cross-source ID/reference reuse
and null agents), then all six rejected deliberate corruption in an isolated
schema. The working build passed nine models and 32 tests. Temporary schema
removed; the recorded Gold population was 11 rows. Fixture SQL is for isolated
copies only; the note explains how to substitute a newly generated schema name.

## 5. Airflow failures and scheduled success

[Note](../notes/2026-11-01_airflow_failure_reporting.md) ·
[build failure](airflow-2026-11-01/build-failure-excerpt.txt) ·
[quality failure](airflow-2026-11-01/quality-failure-excerpt.txt) ·
[scheduled metadata](airflow-2026-11-01/scheduled-run.csv) ·
[scheduled task output](airflow-2026-11-01/scheduled-log-excerpt.txt).

Real dbt errors in isolated projects marked both task and DAG failed, naming the
correct stage and exit code. A separate automatic run had `run_type=scheduled`,
`external_trigger=false`, nine model successes and 32 test passes. It started at
18:25:00 UTC on October 31 and finished about 117 seconds later. The run ID denotes
its data interval; it is not a source-to-Gold latency measurement.

## Reading and reproducing the evidence

Run the current [CDC smoke check](../docs/runbooks/02_poc_execution.md#one-command-cdc-smoke-check),
[quality checks](../docs/runbooks/02_poc_execution.md#targeted-report-quality-checks)
or [Airflow shell check](../docs/runbooks/03_airflow_failures.md#scope-and-proof)
to create new local observations. Full runtime captures under `.runtime/`, dbt
targets/logs and most screenshots are ignored; curated files above are tracked.

Counts and test totals changed as work progressed: baseline 25 tests, CDC fix 26,
quality additions 32. Historical notes retain their measured totals. The current
evidence does not establish a fresh empty-volume installation, Power BI UI refresh,
Linux/EC2 deployment, production load or a deployed Pulse/AI website.
