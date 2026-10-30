# Personal Folder Cold Startup Recovery — 2026-10-30

## Observed Failure

Two full Compose recreations stopped with `mbs-starrocks-fe is unhealthy`.
On the latest attempt FE started at 12:04:29.267 UTC, became unhealthy at
12:06:44.968 UTC, then healthy at 12:07:23.002 UTC without restarting or an OOM.
BE, Airflow init and the scheduler remained in Created state after Compose exited.
The original health check had 12 retries, a 10-second interval and no startup
period. FE needed about 174 seconds. BE DNS warnings were consistent with the
backend container not having been started, rather than evidence of lost data.

## Change

Added `start_period: 5m` to FE and BE health checks in the personal repository.
Kept readiness probes, retry counts, memory settings, images and named volumes.
The unmodified Compose file is saved under ignored
`.runtime/starrocks-startup-recovery/docker-compose.before.yml`.

The feedback command checks that FE is healthy and BE plus the scheduler are
running. Before recovery it failed with FE healthy / BE created / scheduler
created. The same feedback check now passes after the recovery described below.

See the cold-start section of `docs/runbooks/02_poc_execution.md`.
## Verified Recovery

Reran the original full `docker compose --env-file .\.env -f
.\infra\docker-compose\docker-compose.yml -p mbs-poc up -d --force-recreate`
from `D:\Arihant Personal\DataLake_Working`. It completed with exit code 0.
Both FE and BE became healthy; Airflow init exited 0 and the scheduler started.
The original startup feedback check is now green. Cold initialization of the
whole stack, including plugin scanning and Airflow CLI imports, took several
minutes; no further recreation was needed during this wait.

The personal project's exact Windows PowerShell `health:iceberg` and
`health:starrocks` commands both passed. All 16 connector names reloaded,
all connector tasks were RUNNING, and the two source partition offsets were
byte-for-byte identical after canonical JSON conversion. Before/after names and
offsets are saved under ignored `.runtime/starrocks-startup-recovery/`.
All 19 Iceberg registrations remain present. The original Power BI demonstration
row still reads `VISUAL-DEMO-CITY-1` / `VISUAL-APPROVED` in Gold. Customer Lead
Raw contains 30 events. No new sample row was inserted during this recovery.

Inspected plugin, Airflow DAG/plugin and dbt bind mounts: they point inside the
personal folder, including Docker Desktop's equivalent translated host path.
The existing named volumes and images were retained. Only the personal Compose
file, runbook and this note were changed; no Git commit or push was performed.
The optional dashboards remain off. The DAG remains paused as it was during
migration; the next `health:airflow` command unpauses it and runs the scheduled
report verification. A fresh latency test and manual Power BI check remain
follow-up migration checks, not results claimed by this startup recovery.