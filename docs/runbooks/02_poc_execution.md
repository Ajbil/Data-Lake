# POC Execution Runbook

## Purpose

Run the Daily Operations Report POC end to end and collect evidence for acceptance.

## Execution Order

1. Confirm `.env` points to the client DSB-SahiBnk UAT SQL Server and has the Debezium login.
2. Start Kafka, Schema Registry, Kafka Connect, Kafka UI, MinIO, Iceberg REST, StarRocks, and Airflow services.
3. For local testing only, run `bootstrap:report-sample` to create dummy `EKYC_ICICI` and `EKYC_ICICI_Archived` tables, seed data, and CDC. Do not run this on the client DSB-SahiBnk UAT server.
4. Install the Confluent Avro converter plugin and restart Kafka Connect.
5. Register Debezium SQL Server connector for DSB-SahiBnk `EKYC_ICICI` and `EKYC_ICICI_Archived`.
6. Confirm Kafka topics and Schema Registry subjects for the DSB source tables.
7. Install the Iceberg sink plugin and restart Kafka Connect.
8. Register Raw Iceberg sink connectors for the DSB source topics.
9. Confirm Raw Iceberg metadata and Parquet files appear under `lakehouse/warehouse/raw`.
10. Configure StarRocks external Iceberg catalog.
11. Run dbt Silver and Gold models.
12. Enable Airflow DAG every 5 minutes.
13. Connect PowerBI to StarRocks and point it at `analytics.gold_daily_operations_report`.

## Commands

Ubuntu local test:

```bash
./scripts/setup.sh init
./scripts/setup.sh start
./scripts/setup.sh bootstrap:report-sample
./scripts/setup.sh plugin:avro
./scripts/setup.sh restart:connect
./scripts/setup.sh register:source
./scripts/setup.sh health:source
./scripts/setup.sh plugin:iceberg
./scripts/setup.sh restart:connect
./scripts/setup.sh register:raw
./scripts/setup.sh health:iceberg
./scripts/setup.sh health:raw
./scripts/setup.sh bootstrap:starrocks
./scripts/setup.sh health:starrocks
./scripts/setup.sh bootstrap:dbt
./scripts/setup.sh run:dbt
./scripts/setup.sh health:dbt
```

Windows:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1 init
powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1 start
powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1 bootstrap:report-sample
powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1 plugin:avro
docker compose --env-file .env -f infra/docker-compose/docker-compose.yml restart kafka-connect
powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1 register:source
powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1 health:source
powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1 plugin:iceberg
docker compose --env-file .env -f infra/docker-compose/docker-compose.yml restart kafka-connect
powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1 register:raw
powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1 health:iceberg
powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1 health:raw
powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1 bootstrap:starrocks
powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1 health:starrocks
powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1 bootstrap:dbt
powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1 run:dbt
powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1 health:dbt
```

Client UAT flow starts after `.env` has been changed to the DSB-SahiBnk SQL Server host and client-approved Debezium credentials:

```bash
./scripts/setup.sh start
./scripts/setup.sh plugin:avro
./scripts/setup.sh restart:connect
./scripts/setup.sh register:source
./scripts/setup.sh health:source
./scripts/setup.sh plugin:iceberg
./scripts/setup.sh restart:connect
./scripts/setup.sh register:raw
./scripts/setup.sh health:iceberg
./scripts/setup.sh health:raw
./scripts/setup.sh bootstrap:starrocks
./scripts/setup.sh health:starrocks
./scripts/setup.sh bootstrap:dbt
./scripts/setup.sh run:dbt
./scripts/setup.sh health:dbt
```

Never run `bootstrap:report-sample` in the client UAT flow.

## Expected Raw Tables

```text
raw.customer_lead_cdc_connect
raw.customer_lead_icici_cdc_connect
raw.customer_lead_archived_cdc_connect
raw.customer_lead_purge_details_cdc_connect
raw.change_pincode_log_cdc_connect
raw.service_request_assign_log_cdc_connect
raw.service_request_assign_log_archieved_cdc_connect
raw.service_request_assign_log_purge_details_cdc_connect
raw.sr_status_update_log_cdc_connect
raw.sr_status_update_log_archieved_cdc_connect
raw.sr_status_update_log_purge_details_cdc_connect
raw.mas_pincode_cdc_connect
raw.mas_pincode_for_mis_hdfc_cdc_connect
raw.mst_campaign_leads_cdc_connect
```

## Expected dbt Tables

Silver:

```text
default_catalog.analytics.silver_change_pincode_log
default_catalog.analytics.silver_customer_lead_consolidated
default_catalog.analytics.silver_service_request_assign_log_consolidated
default_catalog.analytics.silver_sr_status_update_log_consolidated
default_catalog.analytics.silver_pincode_serviceability
default_catalog.analytics.silver_pincode_state_lookup
default_catalog.analytics.silver_campaign_leads
```

Gold:

```text
default_catalog.analytics.gold_daily_operations_report
```

## Airflow

### Windows latency test and transaction recovery

The local Connect image now pins Kafka client 3.7.2 to fix the transaction-close
deadlock in [KAFKA-16217](https://issues.apache.org/jira/browse/KAFKA-16217).
See [Decision 005](../decisions/005_kafka_client_transaction_recovery.md).
To apply this change to an existing checkout, build and replace only Connect:

```powershell
docker compose --env-file .env -f infra/docker-compose/docker-compose.yml build kafka-connect
docker compose --env-file .env -f infra/docker-compose/docker-compose.yml up -d --no-deps kafka-connect
```

Allow cold plugin discovery to finish before checking task readiness. Keep the
optional Kafka UI and Airflow webserver stopped unless needed on this laptop.
They are in the opt-in `dashboards` profile, and Windows `bootstrap:airflow`
starts the scheduler without the UI. Start a dashboard explicitly when needed:

```powershell
docker compose --env-file .env -f infra/docker-compose/docker-compose.yml up -d --no-deps kafka-ui
docker compose --env-file .env -f infra/docker-compose/docker-compose.yml up -d --no-deps airflow-webserver
```

For normal pipeline verification, run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1 health:iceberg
powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1 latency:report
```

The latency check validates the source and three report sink tasks before any
insert, prints waiting progress every 30 seconds, stops on task/query failures,
and saves completed checkpoints immediately under `screenshots/`. A connector
can say RUNNING while its task is FAILED; always inspect the tasks. Raw success
alone does not prove all report joins or the Gold refresh have completed.

Keep the laptop awake during tests. After sleep or a Docker interruption, check
`health:iceberg` first. If tasks failed, a deliberate `docker restart
mbs-kafka-connect` followed by readiness and health checks can recover them from
saved Kafka offsets. The client patch prevents the observed infinite close
loop; it does not make a sleeping laptop a continuously available server. Never
reset offsets, run `down -v`, or recreate Kafka/the catalog as routine recovery:
Kafka was subsequently migrated to `mbs-poc_kafka-data` mounted at its configured
`/var/lib/kafka/data` log directory; see Decision 007 below. The catalog
was migrated on this laptop to `mbs-poc_iceberg-catalog-data` on 2026-10-29, after
a stopped-container backup and integrity check preserved all 19 registrations.
Its pre-migration copy is `.runtime/iceberg-catalog-backup/catalog-before-20261029.db`.
For another existing checkout, back up and migrate its catalog before applying
the new volume configuration; never replace an unpersisted catalog with an empty
volume. Fresh checkouts create the catalog volume automatically.

The local warehouse FE heap is capped at 1 GiB; its image default was 8 GiB,
larger than this laptop's entire Docker VM. Connect starts at 256 MiB with a
1 GiB maximum. The Kafka latency probe has its own 128 MiB maximum; manual Kafka
CLI commands must likewise override the inherited broker heap, for example:

```powershell
docker exec -e KAFKA_HEAP_OPTS="-Xms32m -Xmx128m" mbs-kafka kafka-consumer-groups --bootstrap-server kafka:9092 --describe --group connect-mbs-iceberg-customer-lead-raw-sink
```

The SQLite catalog uses one JDBC connection, WAL, and a 30-second busy timeout.
See [Decision 006](../decisions/006_local_catalog_and_probe_memory.md).

If the Iceberg plugin loads but a connector returns 404, inspect
`http://localhost:8083/connectors`. An installed plugin is not a saved connector
registration. `health:iceberg` now checks the source and all 15 report sink tasks
and reports missing registrations explicitly. It never registers them silently.

The earlier Kafka configuration mounted a volume at `/bitnami/kafka` while writing
logs to `/tmp/kraft-combined-logs`; container recreation lost Connect configuration,
offsets, CDC topics and control history. Both startup runners now reject that
unmigrated layout. Existing installations must stop writers/broker and preserve
their full log directory in the named volume before applying the new mount.
See [Decision 007](../decisions/007_kafka_log_storage.md).

This laptop's one-time local recovery uses
`ICEBERG_CONTROL_TOPIC=mbs_iceberg_control_recovery_20261029` in `.env` and restores
`register:source` plus `register:raw` from the existing templates. Preserve that
control-topic name on ordinary restarts. Changing it is a deliberate recovery
operation after lost control history, not a routine fix for task errors. The
initial SQL snapshot can add replayed Raw rows; Silver deduplicates them by source
primary key. Windows registration commands print names rather than credential-bearing
configuration responses.

Run the small offline regression checks with:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\health\test_restart_checks.ps1
```
The isolated [Kafka producer regression probe](../../scripts/health/KafkaCloseRegression.java)
requires JDK 17+, the Kafka client jar, and `slf4j-api` on its classpath. It uses
no broker and returns 1 when shutdown is stuck, 0 when close completes. The local
comparison used the cached Maven/JDK image with `--network none` and a 256 MiB
container limit: 3.7.0 reproduced the deadlock; 3.7.2 closed in 0.669 seconds.

```text
URL: http://localhost:8088
Username: admin
Password: admin
DAG: mbs_daily_operations_report
Schedule: every 5 minutes
```

`health:airflow` triggers a normal scheduler-managed run and waits for that run to
succeed. It does not use `airflow dags test`: a test run can overlap an already
scheduled run, and both dbt processes then drop/recreate the same report tables.
The DAG permits one active run at a time. Do not run Windows `run:dbt` while the
Airflow DAG is active; pause the DAG and let its current run finish first.

The DAG has a 10-minute recovery timeout for cold local startup. This is a failure
limit, not a claim that the five-minute freshness target has been met. Measure
freshness separately with the tagged report latency check.

The webserver allows 600 seconds for its Gunicorn master to start on a cold
Windows/Docker laptop. If the old container is stuck restarting with a stale PID
after the former 120-second startup timeout, apply this setting by recreating only
the webserver: `docker compose --env-file .env -f infra/docker-compose/docker-compose.yml up -d --no-deps airflow-webserver`.

For the local single-task POC, Airflow uses two LocalExecutor workers and one UI
worker to limit its memory footprint on a 16 GB laptop. If Docker commands return
HTTP 500 and the Desktop log says `no route to host` for its Linux engine, first
restart Docker Desktop with `docker desktop restart --timeout 180`. Confirm
`docker version` returns both Client and Server, then wait for SQL Server and
StarRocks readiness before retrying the tagged-row test. Do not reset Docker data.

Kafka Connect mounts the Avro converter and Iceberg sink as separate direct child
directories of `/kafka/connect`. Each plugin must have its own dependency class
loader: the converter uses Avro 1.11/Jackson 2.14, while the sink uses Avro
1.12/Jackson 2.18. Mounting their common parent as one plugin location combines
those conflicting dependencies. After changing these mounts, recreate only
`kafka-connect`, then verify source/sink status and a fresh Raw commit without
resetting Kafka offsets or lake tables.

## Cold StarRocks Startup on Windows

FE and BE health checks allow a five-minute startup grace period. A cold local
FE replay took about 174 seconds on 2026-10-30, exceeding the old health-check
failure window. Docker marked it unhealthy and Compose stopped dependency
startup; the same FE became healthy 39 seconds later without restarting.
A successful check still releases dependants immediately during the grace
period. Persistent failures become unhealthy after the grace period and retries.

If Compose has already stopped with FE unhealthy, inspect its current state.
Once FE is healthy, resume with `setup.ps1 start` from the current project folder.
Repeated full `up --force-recreate` restarts the cold initialization process.
Keep the existing named volumes; the catalog's missing Compose-label warning
is separate from FE readiness and is not a reason to replace that volume.

## Proof Points

Local SQL sample:

- `EKYC_ICICI` and `EKYC_ICICI_Archived` exist.
- All DSB report source tables exist.
- Seed rows cover:
  - `Fresh`
  - `RPush`
  - `Serviceable`
  - `Non-Serviceable`
  - `High-priority`
  - `Non-priority`
  - active, archived, purge, and ICICI lead paths.
- CDC is enabled on every captured source table.

Debezium/Kafka:

- Connector `mbs-sqlserver-cdc` is `RUNNING`.
- Topics exist for the DSB source tables.
- Schema Registry subjects exist for each captured table.

Iceberg/MinIO:

- `lakehouse` bucket exists.
- Raw Iceberg tables exist.
- MinIO contains metadata and data files under `warehouse/raw`.

StarRocks/dbt:

- `SHOW TABLES FROM iceberg_catalog.raw` lists DSB Raw tables.
- `dbt run` builds the Silver and Gold models.
- `dbt test` passes.
- `SELECT COUNT(*) FROM default_catalog.analytics.gold_daily_operations_report` succeeds.

PowerBI:

- PowerBI connects through StarRocks MySQL protocol.
- Report uses `analytics.gold_daily_operations_report`.
- Refresh completes within the 5-minute pipeline target after new eligible source changes arrive.

## Large Initial Load Path

For large client datasets, use bulk initial load plus CDC cutover instead of relying only on Debezium initial snapshot.

1. Enable CDC on all in-scope source tables.
2. Record export start LSN with `sys.fn_cdc_get_max_lsn()` and record `SYSUTCDATETIME()`.
3. Bulk export existing source rows with the client-approved method.
4. Load exported rows into Raw Iceberg as snapshot-shaped append-only records.
5. Start Debezium from the cutover point for ongoing CDC.
6. Confirm CDC changes after the cutover point land in Kafka and Raw Iceberg.
7. Build initial Silver and Gold from Raw.
8. Validate the Gold report against client row counts, totals, and report screenshots.

## Known Client Decision

Several report fields are decrypted in SQL Server views via `dbo.DecryptedData()`. CDC from base tables captures stored base-table values. Before production hardening, the client must approve whether decrypted report-safe columns are provided source-side, whether decryption logic can be reused downstream, or whether those PII fields should be masked/excluded.
