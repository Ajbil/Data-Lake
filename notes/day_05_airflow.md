# Day 05 Airflow

## Goal

Run dbt on a 5-minute Airflow schedule.

## Why This Matters

Airflow provides the recurring transformation cycle needed for the 5-minute PowerBI acceptance target.

## Commands or Actions

- Added a local Airflow image with `dbt-starrocks`.
- Added `mbs_dbt_silver_gold` DAG under [infra/airflow/dags](C:\Users\caw-dev\Desktop\mbs\infra\airflow\dags).
- Started Airflow with:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1 bootstrap:airflow
```

- Verified Airflow with:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1 health:airflow
```

## Evidence Captured

- Airflow UI reachable.
- DAG scheduled every 5 minutes.
- DAG runs `dbt run` and `dbt test`.
- Synchronous DAG verification succeeded.
- DAG rebuilt 3 dbt models and passed 14 dbt tests.
- Final synchronous verification completed successfully in about 122 seconds.

## Observations

- Airflow UI is `http://localhost:8088` with local POC credentials `admin` / `admin`.
- Airflow must wait for StarRocks FE, StarRocks BE, and Iceberg REST; otherwise dbt can fail on external catalog reads.
- The scheduled task uses `dbt run` and `dbt test` directly. `dbt debug` was intentionally removed because the Airflow image does not need Git for scheduled execution.
- Installing `dbt-starrocks` into the base Airflow image upgrades `protobuf`; this produced provider-package compatibility warnings. The POC DAG passed, but production should use a curated image with pinned constraints.
- Cold dbt parse/catalog work can make the first Airflow test slower than normal warm runs.

## Issues and Follow-Ups

- Production Airflow should not use `admin` / `admin`.
- Move Airflow secrets and StarRocks credentials into a proper secrets backend or client-approved environment injection.
- Decide whether Airflow should trigger PowerBI refresh through a gateway/API in later milestones.

## Local Recovery on 2026-10-28

- Windows dbt built all 9 report models and passed all 25 data tests before the Airflow check.
- The old health command unpaused the DAG and then executed `airflow dags test` outside the scheduler. Its test overlapped a resumed scheduled run; `silver_campaign_leads` failed with `errno: table already exists` while both runs rebuilt the same tables.
- Changed the health command to trigger a unique scheduler-managed run, poll that exact run, and fail on a failed run or timeout. The existing `max_active_runs=1` now protects health checks as well as scheduled runs.
- Later scheduled runs hit the old four-minute timeout. A recovery run completed in approximately 4 minutes 10 seconds after allowing ten minutes. The five-minute cadence is unchanged; freshness must still be measured separately.
- The webserver also restarted because its Gunicorn master exceeded its startup allowance. A temporary isolated `cached_app()` diagnostic completed successfully; traceback snapshots showed progress through library imports, SQLAlchemy mapping, and API schema setup, not a database lock. Both 120 and 300 seconds were insufficient under local load, so the startup allowance is 600 seconds. Recreate only the webserver container to apply it and clear stale PID state.
- Do not run host dbt commands concurrently with an active Airflow transformation. Pause the DAG and let the current run finish first.
- Live regression check: `powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1 health:airflow` exited successfully. Run `health_875ba75cb162466aae2ad5db9db4f71a` rebuilt 9 models, passed 25 tests, and completed in 246 seconds. Airflow task timestamps showed zero overlapping transformation tasks; the five-minute schedule was enabled afterward.
- UI verification: the webserver became healthy with zero restarts after the 600-second setting was applied. `http://localhost:8088/health` reported both the metadatabase and scheduler as healthy. The temporary diagnostic container removed itself after its successful startup check.

## Docker and Ingestion Recovery Later on 2026-10-28

- `latency:report` initially failed before SQL execution with Docker API HTTP 500. Desktop logs showed `no route to host` for the Linux engine. A normal `docker desktop restart --timeout 180` restored access; client and server both reported 29.7.2, so no API-version override was needed. The original tag had zero source rows before retrying.
- Available Windows memory fell below 1 GB during startup. Limited LocalExecutor parallelism to 2 and webserver workers to 1. Temporarily stopping Kafka UI and Airflow UI freed memory while the core pipeline recovered.
- Kafka group-coordination requests timed out, and the sink lost its active consumer. Restarted the existing broker and Connect containers without resetting topics, offsets, or data.
- Corrected Connect plugin isolation: Avro and Iceberg now mount as separate direct children of `/kafka/connect`, instead of sharing a class loader containing conflicting Avro/Jackson/logging dependencies.
- After the sink caught up, commits still failed with catalog HTTP 500 caused by `SQLITE_BUSY: database is locked`. Restarting the existing catalog container cleared its open SQLite connections. Do not recreate this container casually: its SQLite file is still in the container filesystem. The queued original test row then committed to Raw.
- Final regression: the exact `scripts/setup.ps1 latency:report` command exited successfully for `CDC-LATENCY-20261028175702`. Checkpoints were SQL 2.194 s, Kafka 43.063 s, Raw 44.089 s, Airflow trigger 89.153 s, and Gold 139.395 s. Evidence: `screenshots/CDC-LATENCY-20261028175702-report-latency.csv`.
- The resulting Gold row was Fresh, High-priority, Serviceable, assigned to AG001. Optional dashboards were left stopped to conserve memory; the source, ingestion, warehouse, and Airflow scheduler remained running.
