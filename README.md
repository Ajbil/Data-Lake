# MBS Data Lake POC

Fresh proof-of-concept scaffold for:

```text
SQL Server 2019 CDC -> Debezium -> Kafka -> Kafka Connect -> Iceberg Raw on MinIO -> dbt Silver/Gold -> StarRocks external Iceberg catalog -> PowerBI
```

This workspace preserves `Data_lake_poc_new_architecture.png` and intentionally leaves any existing `data_lake` folder untouched.

## Why This Pipeline

| Stage | Technology | Why chosen | Previous | Next |
| --- | --- | --- | --- | --- |
| Source | SQL Server 2019 CDC | Native change capture for the expected source database family. | Application writes | Debezium |
| CDC | Debezium | Mature SQL Server CDC connector with snapshot and schema history support. | SQL Server CDC | Kafka |
| Events | Kafka | Durable buffer for replay, decoupling, and topic visibility. | Debezium | Kafka Connect |
| Schemas | Schema Registry | Versioned Avro schemas for CDC contracts. | Debezium | Connect sinks |
| Raw ingest | Kafka Connect Iceberg sink, with Python writer fallback | Declarative connector path is preferred; the fallback keeps the POC moving when the sink plugin is unavailable. | Kafka | Iceberg Raw |
| Storage | MinIO | Self-hosted S3-compatible object storage for EC2/local POC. | Iceberg writers | Iceberg catalog |
| Table format | Iceberg REST catalog | Open table metadata, snapshots, schema evolution, engine interoperability. | MinIO | StarRocks |
| Transform | dbt-starrocks | Versioned SQL transformations and tests. | StarRocks Raw | Silver/Gold |
| Query | StarRocks | Fast SQL serving layer with MySQL protocol for BI. | Iceberg/dbt | PowerBI |
| BI | PowerBI | Expected analyst-facing dashboard surface. | StarRocks | Demo chart |

## Scope

Included:

- DSB-SahiBnk Daily Operations Report source tables from `EKYC_ICICI` and `EKYC_ICICI_Archived`.
- Debezium SQL Server connector.
- Kafka, Schema Registry, Kafka Connect, and Kafka UI.
- MinIO-backed append-only Iceberg Raw.
- dbt Silver models that recreate the report's consolidated views and Gold `gold_daily_operations_report`.
- StarRocks external Iceberg catalog.
- Airflow DAG every 5 minutes.
- PowerBI through StarRocks MySQL protocol.
- Lightweight Prometheus, Grafana, Loki, and Promtail guidance.

Excluded:

- Chatbot/LLM, RBAC, HA, DR, production IAM/secrets, Excel ingestion, and PII tokenization.

## Project Command Runner

For the 2026-10-29 Windows latency recovery, see the
[execution runbook](docs/runbooks/02_poc_execution.md#windows-latency-test-and-transaction-recovery).
The local configuration uses a patched Kafka client, bounded Java heaps, and a
persistent SQLite catalog. Existing installations must migrate their old catalog
before applying its new volume configuration; this laptop's 19 registrations
have already been migrated. Keep the optional Kafka and Airflow dashboards off
unless needed on the 16 GB laptop.
Kafka's logs and KRaft metadata now use its named volume at `/var/lib/kafka/data`.
Existing brokers with the older mismatched mount require preserved migration
before startup; see [Decision 007](docs/decisions/007_kafka_log_storage.md).

This POC uses [scripts/setup.ps1](C:\Users\caw-dev\Desktop\mbs\scripts\setup.ps1) as the single command entry point, similar to `package.json` scripts in Node or a Python task runner.

Show available commands:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1 help
```

On Ubuntu/EC2, use the Linux runner instead of PowerShell:

```bash
chmod +x scripts/setup.sh
./scripts/setup.sh help
```

The Linux runner mirrors the Windows command names where practical. It keeps the server flow Bash-native and uses Docker, curl, Python 3, and Docker Compose directly.

Typical Ubuntu local test flow for the Avro/Schema Registry path:

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
./scripts/setup.sh bootstrap:airflow
./scripts/setup.sh health:airflow
```

For client UAT on the DSB-SahiBnk server, do not run `bootstrap:report-sample`. That command creates local dummy tables only. Point `.env` to the DSB-SahiBnk SQL Server and start from `register:source`.

Ubuntu prerequisites:

```bash
sudo apt update
sudo apt install -y git curl python3 python3-venv
```

## Local SQL Smoke Flow

Run from `C:\Users\caw-dev\Desktop\mbs`:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1 init
powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1 start
powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1 bootstrap:local-sql
powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1 health:services
```

What these commands do:

| Command | Purpose |
| --- | --- |
| `init` | Creates `.env` from `.env.example` if needed. |
| `start` | Starts SQL Server 2019, Kafka, Schema Registry, Kafka Connect, and Kafka UI. |
| `bootstrap:local-sql` | Creates the legacy local `mbs_poc` smoke database, tables, seed data, CDC, and retention. |
| `bootstrap:report-sample` | Creates local `EKYC_ICICI` and `EKYC_ICICI_Archived` sample report tables, seed rows, and CDC. |
| `health:services` | Verifies Docker services and platform endpoints. |
| `test:cdc` | Windows: checks a new synthetic lead through insert/update/delete/rebuild, saves evidence and cleans up its own row. |
| `ps` | Shows container status. |
| `stop` | Stops containers without deleting Docker volumes. |

EC2 daily shutdown note: long-running services use `restart: unless-stopped`, so Docker should bring them back when the instance starts again. One-shot init services such as `create-minio-bucket` and `airflow-init` do not restart automatically; run `powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1 start` if volumes are recreated or init dependencies need to be re-applied.

## CDC End-to-End Regression

With the report pipeline already healthy, run the Windows end-to-end regression:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup.ps1 test:cdc
```

It temporarily pauses scheduled report rebuilds, restores the original pause
state, and leaves existing demonstration rows intact. See the
[smoke-check runbook](docs/runbooks/02_poc_execution.md#one-command-cdc-smoke-check).

## Source CDC Startup Flow

After services are running, register Debezium and verify MinIO/Iceberg:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1 plugin:avro
docker compose --env-file .env -f infra/docker-compose/docker-compose.yml restart kafka-connect
powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1 register:source
powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1 health:source
```

Source CDC adds:

| Service or asset | Purpose |
| --- | --- |
| `mbs-sqlserver-cdc` connector | Debezium SQL Server source connector. |
| `infra/kafka-connect/plugins/avro-converter` | Confluent Avro converter jars used by Kafka Connect to register CDC schemas. |
| `mbs-minio` | S3-compatible object storage for Iceberg. |
| `lakehouse` bucket | Iceberg warehouse bucket. |
| `mbs-iceberg-rest` | Iceberg REST catalog endpoint. |

Current Avro note: Kafka Connect now uses `io.confluent.connect.avro.AvroConverter` for keys and values, with Schema Registry at `http://schema-registry:8081`. Kafka topic output is binary Avro, and Schema Registry subjects prove the contract is registered. Existing local topics may contain older JSON-with-schema records from before the migration; avoid resetting consumer groups against the beginning of those topics unless the topics are recreated cleanly.

For the DSB-SahiBnk report path, set `.env` values for the client SQL Server host, port, Debezium login, topic prefix, and captured databases before registering the connector. The default captured databases are `EKYC_ICICI,EKYC_ICICI_Archived`.

```env
MSSQL_HOST=<DSB-SahiBnk UAT SQL Server host/IP>
MSSQL_PORT=1433
MSSQL_CAPTURE_DATABASES=EKYC_ICICI,EKYC_ICICI_Archived
KAFKA_TOPIC_PREFIX=mbs_poc
MSSQL_DEBEZIUM_USER=<client-approved-cdc-user>
MSSQL_DEBEZIUM_PASSWORD=<password>
```

For a local end-to-end test without client UAT, run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1 bootstrap:report-sample
```

This creates dummy DSB report tables and rows covering Fresh, RPush, serviceable, non-serviceable, high-priority, non-priority, active, archived, purge, and ICICI lead paths.

Do not run `bootstrap:report-sample` against the client DSB-SahiBnk UAT server.

## Raw Iceberg Startup Flow

After source CDC is healthy, verify Raw Iceberg ingestion:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1 bootstrap:python
powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1 health:raw
```

Raw Iceberg adds:

| Asset | Purpose |
| --- | --- |
| [requirements-day3.txt](C:\Users\caw-dev\Desktop\mbs\requirements-day3.txt) | Python dependencies for the fallback Raw Iceberg writer. |
| [scripts/lake/write_raw_iceberg_day3.py](C:\Users\caw-dev\Desktop\mbs\scripts\lake\write_raw_iceberg_day3.py) | Reads Debezium Kafka topics and appends CDC envelopes into Iceberg Raw tables. |
| `.runtime/day3_offsets.json` | Ignored local checkpoint file storing the next Kafka offset per topic partition. |
| [infra/kafka-connect/plugins/iceberg-sink/pom.xml](C:\Users\caw-dev\Desktop\mbs\infra\kafka-connect\plugins\iceberg-sink\pom.xml) | Repeatable dependency definition for the Apache Iceberg Kafka Connect sink plugin. |
| `raw.customer_lead_cdc_connect` and related DSB tables | Append-only Iceberg tables written by Kafka Connect Iceberg sink. |

Preferred Kafka Connect sink setup:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1 plugin:iceberg
docker compose --env-file .env -f infra/docker-compose/docker-compose.yml restart kafka-connect
powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1 register:raw
powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1 health:iceberg
```

Raw Iceberg proof:

- Kafka Connect loads `org.apache.iceberg.connect.IcebergSinkConnector` version `1.8.1`.
- DSB source topics have matching Raw Iceberg sink connectors.
- MinIO contains Iceberg `metadata/*.metadata.json`, manifest Avro files, snapshot Avro files, and Parquet data files under `lakehouse/warehouse/raw`.

## StarRocks And dbt Startup Flow

After Raw Iceberg is healthy, start StarRocks, create the Iceberg catalog, and build dbt Silver/Gold:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1 start
powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1 bootstrap:starrocks
powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1 health:starrocks
powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1 bootstrap:dbt
powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1 run:dbt
powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1 health:dbt
```

StarRocks and dbt add:

| Asset | Purpose |
| --- | --- |
| `mbs-starrocks-fe` | StarRocks frontend, MySQL protocol endpoint, and query coordinator. |
| `mbs-starrocks-be` | StarRocks backend worker that executes scans and stores internal dbt tables. |
| [infra/starrocks/catalogs/create_iceberg_catalog.sql](C:\Users\caw-dev\Desktop\mbs\infra\starrocks\catalogs\create_iceberg_catalog.sql) | Creates `iceberg_catalog` pointing to Iceberg REST and MinIO. |
| [dbt/dbt_project.yml](C:\Users\caw-dev\Desktop\mbs\dbt\dbt_project.yml) | dbt project config for StarRocks-managed Silver/Gold tables. |
| [dbt/models/raw/sources.yml](C:\Users\caw-dev\Desktop\mbs\dbt\models\raw\sources.yml) | Raw source definitions for Iceberg CDC tables. |
| [dbt/models/silver/silver_customer_lead_consolidated.sql](C:\Users\caw-dev\Desktop\mbs\dbt\models\silver\silver_customer_lead_consolidated.sql) | Recreates the customer lead consolidated view. |
| [dbt/models/silver/silver_service_request_assign_log_consolidated.sql](C:\Users\caw-dev\Desktop\mbs\dbt\models\silver\silver_service_request_assign_log_consolidated.sql) | Recreates the assignment log consolidated view. |
| [dbt/models/silver/silver_sr_status_update_log_consolidated.sql](C:\Users\caw-dev\Desktop\mbs\dbt\models\silver\silver_sr_status_update_log_consolidated.sql) | Recreates the SR status log consolidated view. |
| [dbt/models/gold/gold_daily_operations_report.sql](C:\Users\caw-dev\Desktop\mbs\dbt\models\gold\gold_daily_operations_report.sql) | PowerBI-facing Daily Operations Report table. |

StarRocks and dbt proof from the current workspace:

- StarRocks FE/BE are healthy.
- `iceberg_catalog.raw` is queryable from StarRocks.
- Raw DSB tables are queryable through `iceberg_catalog.raw`.
- `dbt run` builds the Silver consolidated models and `analytics.gold_daily_operations_report`.
- `dbt test` validates report labels and key fields.

## Airflow Startup Flow

After dbt is healthy, start Airflow and verify the scheduled dbt DAG:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1 bootstrap:airflow
powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1 health:airflow
```

Airflow adds:

| Asset | Purpose |
| --- | --- |
| `mbs-airflow-db` | PostgreSQL metadata database for Airflow. |
| `mbs-airflow-webserver` | Airflow UI on `http://localhost:8088`. |
| `mbs-airflow-scheduler` | Runs the dbt DAG every 5 minutes. |
| [infra/airflow/dags/mbs_dbt_silver_gold.py](C:\Users\caw-dev\Desktop\mbs\infra\airflow\dags\mbs_dbt_silver_gold.py) | Airflow DAG `mbs_daily_operations_report` that runs `dbt run` and `dbt test`. |
| [infra/airflow/Dockerfile](C:\Users\caw-dev\Desktop\mbs\infra\airflow\Dockerfile) | Local Airflow image with `dbt-starrocks` installed. |

Airflow UI credentials for the local POC:

```text
Username: admin
Password: admin
```

Airflow proof from the current workspace:

- Airflow webserver is healthy on port `8088`.
- Airflow scheduler sees DAG `mbs_daily_operations_report`.
- DAG schedule is every 5 minutes.
- `health:airflow` triggers a normal scheduler-managed run and waits for its result.
- `max_active_runs=1` keeps scheduled and health-check runs from rebuilding the same tables concurrently.
- The current report project contains 9 dbt models and 32 data tests, including a
  keyed CDC current-state regression fixture and six targeted quality checks.
  See the [CDC correctness check](docs/runbooks/02_poc_execution.md#basic-keyed-cdc-correctness-check)
  and [report quality checks](docs/runbooks/02_poc_execution.md#targeted-report-quality-checks).
- Report task logs identify the failed dbt stage and preserve its exit code.
  See [Airflow failure inspection and recovery](docs/runbooks/03_airflow_failures.md).

## Legacy Load And Failure Harness

Legacy load and failure harnesses:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1 load:day6
powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1 latency:day6
powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1 failure:day6-safe
```

Legacy load assets:

| Asset | Purpose |
| --- | --- |
| [loader/kyc_load.ps1](C:\Users\caw-dev\Desktop\mbs\loader\kyc_load.ps1) | Inserts tagged KYC rows at the target 10 rows/sec for 30 minutes. |
| [scripts/latency/measure.ps1](C:\Users\caw-dev\Desktop\mbs\scripts\latency\measure.ps1) | Tracks one tagged row through SQL Server, Kafka, Iceberg Raw, Airflow/dbt, Silver, and Gold. |
| [scripts/failure](C:\Users\caw-dev\Desktop\mbs\scripts\failure) | Safe failure-scenario scripts for Kafka Connect pause, schema change, and StarRocks BE restart. |
| [docs/operations/02_failure_tests.md](C:\Users\caw-dev\Desktop\mbs\docs\operations\02_failure_tests.md) | Failure-test runbook including risk-gated manual scenarios. |

Legacy load notes:

- CDC retention exceeded and object-storage low-space tests are intentionally manual/risk-gated because they can damage local state.
- PowerBI refresh remains manual from PowerBI Desktop.
- Latency CSV evidence is written under `screenshots/`.

## Full POC Startup Flow

Later milestone steps will extend [scripts/setup.ps1](C:\Users\caw-dev\Desktop\mbs\scripts\setup.ps1). The full flow remains:

1. Start Docker Compose services.
2. Bootstrap SQL Server database, tables, seed data, and CDC.
3. Register Debezium connector.
4. Verify events in Kafka UI and schemas in Schema Registry.
5. Create MinIO `lakehouse` bucket and validate Iceberg REST catalog.
6. Register Iceberg sink, or use the Raw writer fallback if blocked.
7. Configure StarRocks external Iceberg catalog.
8. Run dbt Silver/Gold.
9. Enable Airflow 5-minute DAG.
10. Connect PowerBI and refresh the Daily Operations Report.

## Expected Ports

| Service | Port |
| --- | --- |
| SQL Server | `11433` on host, mapped to `1433` in container |
| Kafka | `9092` |
| Schema Registry | `8081` |
| Kafka Connect | `8083` |
| Kafka UI | `8080` |
| MinIO API | `9000` |
| MinIO Console | `9001` |
| Iceberg REST catalog | `8181` |
| StarRocks FE HTTP | `8030` |
| StarRocks MySQL | `9030` |
| StarRocks BE web | `8040` |
| Airflow UI | `8088` |
| Prometheus | `9090` |
| Grafana | `3000` |
| Loki | `3100` |

## Service Ownership

| Area | Primary POC owner | Acceptance evidence |
| --- | --- | --- |
| SQL Server and CDC | Data engineering with DBA review | CDC enabled, 7-day retention, change rows visible |
| Kafka and Debezium | Data engineering | Connector running, topics populated, schemas registered |
| MinIO and Iceberg | Data platform engineering | Raw append-only files and Iceberg metadata visible |
| StarRocks | Analytics platform engineering | External catalog queries succeed |
| dbt | Analytics engineering | Silver/Gold models build and tests pass |
| Airflow | Data platform engineering | 5-minute DAG completes successfully |
| PowerBI | BI/analytics user | Chart updates after refresh |
| Monitoring | Shared POC team | Basic health/log dashboards available |

## Demo Script

1. Show the architecture image.
2. Insert or update a report-relevant lead/status/assignment row in DSB-SahiBnk `EKYC_ICICI` UAT with client approval.
3. Show SQL Server CDC captured the change.
4. Show the event in Kafka UI.
5. Show Raw Iceberg files and metadata in MinIO.
6. Query Raw, Silver, and Gold in StarRocks.
7. Run or wait for the Airflow dbt DAG.
8. Refresh PowerBI and show the Daily Operations Report.
9. Review latency, failure tests, risks, and DBA questions.

## Acceptance Criteria

- SQL Server row appears in PowerBI within 5 minutes.
- Raw CDC is preserved append-only in Iceberg on MinIO.
- Silver/Gold dbt models produce queryable business data.
- StarRocks reads Gold Iceberg tables.
- PowerBI connects to StarRocks successfully.
- Gotchas, failure scenarios, DBA questions, and project risks are documented.

## Escalation

If the Iceberg Kafka Connect sink blocks progress, escalate and switch to a controlled writer path. The fallback path keeps the local PyIceberg writer available, but Kafka Connect now has the Apache Iceberg sink plugin installed and verified.
