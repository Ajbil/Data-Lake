# POC execution checks and recovery

For the current local synthetic-data setup, follow the [README](../../README.md#run-locally-on-windows).
It is the single setup sequence; the reference sections below cover data inventory,
recovery and the checks added during the six-step cleanup. Use
[the evidence index](../../evidence/README.md) for recorded results and
[the Airflow guide](03_airflow_failures.md) for failed report runs.

`bootstrap:report-sample` drops/recreates the sample tables and CDC instances.
Use it only for a new disposable local dataset, never for daily recovery or an
external/customer database. A working installation should use the README's daily
checks and preserve its existing volumes, registrations and offsets.

## Alternative runtimes and historical material

The README uses dbt in the existing Airflow container. For the optional Windows
host-Python route, create `.venv` with `bootstrap:python` before `bootstrap:dbt`,
then use `run:dbt` only while scheduled report work is paused and drained.
Those commands install the older fallback tooling as well.

The Linux runner supports ingestion, StarRocks and local dbt commands; inspect
`./scripts/setup.sh help` for its actual command set. It does not implement the
Windows Airflow bootstrap/health or CDC-smoke commands. Linux/EC2 and external
client integration were not revalidated by this cleanup. The bulk-export/client
notes below preserve earlier planning and are not acceptance claims for the
current synthetic demo.
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
raw.mbs_user_cdc_connect
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
default_catalog.analytics.silver_mbs_user
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

PowerBI (optional manual acceptance checks, not current cleanup evidence):

- PowerBI connects through StarRocks MySQL protocol.
- Report uses `analytics.gold_daily_operations_report`.
- Optional historical BI target: measure refresh separately; the current cleanup does not establish five-minute source-to-BI freshness.

## Large Initial Load Path

Historical client-source proposal, not an implemented or benchmarked path for
the current synthetic demo. Current source registration uses an initial snapshot.

For large client datasets, use bulk initial load plus CDC cutover instead of relying only on Debezium initial snapshot.

1. Enable CDC on all in-scope source tables.
2. Record export start LSN with `sys.fn_cdc_get_max_lsn()` and record `SYSUTCDATETIME()`.
3. Bulk export existing source rows with the client-approved method.
4. Load exported rows into Raw Iceberg as snapshot-shaped append-only records.
5. Start Debezium from the cutover point for ongoing CDC.
6. Confirm CDC changes after the cutover point land in Kafka and Raw Iceberg.
7. Build initial Silver and Gold from Raw.
8. Validate the Gold report against client row counts, totals, and report screenshots.

## Basic Keyed CDC Correctness Check

The 26th dbt data test is a self-contained StarRocks fixture of the shared keyed
CDC rule. Run it with the existing configured dbt runtime:

```powershell
docker exec -w /opt/airflow/dbt -e STARROCKS_DBT_HOST=starrocks-fe -e DBT_PROFILES_DIR=/opt/airflow/dbt mbs-airflow-scheduler /home/airflow/.local/bin/dbt test --select cdc_current_rows
```

For an actual synthetic lead that has already been deleted and whose delete is
present in Raw, rebuild the lead/report models, then run the read-only assertion:

```powershell
docker exec -w /opt/airflow/dbt -e STARROCKS_DBT_HOST=starrocks-fe -e DBT_PROFILES_DIR=/opt/airflow/dbt mbs-airflow-scheduler /home/airflow/.local/bin/dbt run --select silver_customer_lead_consolidated gold_daily_operations_report
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\health\test_cdc_deleted_lead.ps1 -Tag CDC-FIX-20261031-131923
```

The assertion requires a real Raw `d` event and zero current Silver/Gold rows; an
unknown tag cannot pass. It does not insert or delete anything. The recorded tag
exists in this local evidence dataset; another installation must prepare its own
uniquely tagged synthetic lead, observe its insert, delete it at the source and
wait for its Raw delete. Never use original demonstration/customer rows.

For manual rebuild experiments, pause the report DAG first, wait for active runs
to finish, and restore its original pause state afterward to avoid concurrent
table replacement. Source/sink services continue ingesting. Details and measured
before/after results are in [the CDC correctness note](../../notes/2026-10-31_cdc_correctness.md).

This check covers keyed rows only. The active assignment log lacks a stable row
key and remains outside the keyed current-state guarantee.

## One-Command CDC Smoke Check

From the project root on Windows, with the existing report pipeline running:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup.ps1 test:cdc
```

The command requires healthy source/sink tasks and the existing local SQL Server,
StarRocks and Airflow containers. It creates one GUID-tagged synthetic lead,
verifies initial and updated values in both Silver/Gold, deletes it, then verifies
absence after two builds. Raw must contain each real source change before a build
starts. It never reseeds, resets offsets, restarts failed connectors or edits an
existing demonstration row.

Scheduled rebuilds are paused during the check and the original pause state is
restored in `finally`. An active run is allowed to finish; queued runs cause a
clear failure rather than being cancelled. Run one test at a time and avoid other
manual dbt builds. Polling defaults to 300 seconds per stage; each dbt invocation
has a 300-second timeout. Override those limits through the direct script if needed.

Per-run `summary.json`, `checkpoints.csv` and command logs are saved under ignored
`.runtime/cdc-smoke/<tag>/`. A normal run exits 0 only if the lifecycle and cleanup
checks pass. Failures exit nonzero and retain their original error; cleanup errors
are recorded separately. Source cleanup is attempted even if ingestion is broken;
downstream cleanup cannot be promised while the pipeline is unavailable.

To deliberately exercise cleanup after an inserted row, use this diagnostic
command. It is expected to exit nonzero even when cleanup succeeds:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\health\test_cdc_pipeline.ps1 -FailAfterInsert
```

The local test does not measure normal Airflow scheduling latency, sustained load,
or the keyless assignment branch. Abrupt termination can prevent cleanup; use the
saved tag and `CDC-SMOKE-CHECK` marker for targeted recovery. See the
[implementation and evidence note](../../notes/2026-10-31_cdc_smoke_check.md).

## Targeted Report Quality Checks

The existing Airflow `dbt test` command automatically runs all 32 tests. Six tests
tagged `quality` cover the bounded Step 4 additions. With the local containers
running, test the last completed Silver/Gold build using:

```powershell
docker exec -w /opt/airflow/dbt -e STARROCKS_DBT_HOST=starrocks-fe -e DBT_PROFILES_DIR=/opt/airflow/dbt mbs-airflow-scheduler /home/airflow/.local/bin/dbt test --select tag:quality
```

Avoid concurrent table replacement: allow queued work to finish while unpaused,
then pause the report DAG and let any running task finish. Confirm no active runs
remain and restore the original pause state after testing. Paused DAGs do not
drain queued runs. The scheduled task already tests after its own build.

| Check | Contract |
| --- | --- |
| Silver physical lead grain | At most one current row per `(source_table, customer_id)`. The same ID/reference in different physical tables is allowed. |
| Gold population | Counts per `(lead_source_table, order_number)` equal eligible Silver counts, catching missing/extra rows and join multiplication without assuming globally unique ARNs. |
| Agent relationship | Every non-null Gold `agent_id` exists in `silver_mbs_user.user_id`. Null means unassigned and is allowed. |
| Three required labels | `serviceable_pincode`, `record_type`, and `champaines` cannot be null. Existing accepted-value tests reject unknown labels. |

Gold eligibility follows the current report's mobile exclusions and date window
(month start two months before the current date, using created OR updated date).
If those business rules change, review the population test alongside the model.
Do not compare all Raw/Silver rows directly with the filtered Gold report.

Required, accepted serviceability labels make Serviceable + Non-Serviceable equal
the Gold population; a separate sum of the same categories would duplicate this
contract. These checks do not enforce one business lead across active/archive
tables, and do not require every lead to have an assignment, campaign, or status log.

On failure, use the named test and its compiled SQL under `dbt/target/compiled/`
to inspect failing keys locally. Correct the data/model or explicitly review a
changed business rule before rerunning. Do not bypass a failure to publish a
snapshot. The existing DAG builds tables before testing, so a failed test marks
the run failed but does not roll back already rebuilt tables.

The [Step 4 note](../../notes/2026-10-31_targeted_quality_checks.md) records the
isolated good/bad fixture procedure and execution evidence. It uses temporary
copies of three derived tables; it does not write source or Raw data.

## Known Client Decision

Several report fields are decrypted in SQL Server views via `dbo.DecryptedData()`. CDC from base tables captures stored base-table values. Before production hardening, the client must approve whether decrypted report-safe columns are provided source-side, whether decryption logic can be reused downstream, or whether those PII fields should be masked/excluded.
