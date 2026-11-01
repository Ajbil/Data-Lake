# Implemented data flow

This is the current local synthetic-data path. Older client/milestone documents
are background; [the README](../../README.md) is the setup entry point and
[the evidence index](../../evidence/README.md) distinguishes verified results.

```text
SQL Server CDC -> Debezium -> Kafka Avro -> Kafka Connect Iceberg sinks
    -> Raw Iceberg files in MinIO, registered by Iceberg REST
    -> StarRocks external iceberg_catalog.raw
    -> dbt SQL -> native default_catalog.analytics Silver/Gold

Airflow schedules dbt run + dbt test every five minutes.
SQL clients and optional Power BI read the native Gold report.
```

## Technology roles and operational fallback

| Technology | Why used | Input | Consumer | Proof | If blocked |
| --- | --- | --- | --- | --- | --- |
| SQL Server 2019 CDC | Capture row changes from the relational source | Synthetic application tables | Debezium | CDC-enabled tables and controlled source mutations | Inspect SQL Server Agent/capture jobs; preserve offsets |
| Debezium 2.7 | Initial snapshot plus ongoing SQL Server changes | CDC metadata and rows | Kafka | Source task RUNNING and new events arrive | Inspect the failing source task; resolve source/contract issue |
| Kafka | Separate change capture from lake writes | Debezium Avro records | Iceberg sinks | Topics/offsets advance; Raw receives the event | Inspect broker and persistent storage; no offset reset as routine recovery |
| Schema Registry / Avro | Typed, registered CDC contracts | Connect converter schemas | Kafka consumers/sinks | Source subjects are registered | Check converter installation and subjects; no silent format switch |
| Kafka Connect Iceberg sink 1.8.1 | Declarative ingestion per topic | Fifteen report topics | Raw Iceberg | All 15 sink tasks RUNNING and Raw rows/files visible | Diagnose failed task/commit; alternate writer requires a separately validated contract |
| MinIO | Local S3-compatible file storage | Iceberg data/metadata writes | REST catalog and StarRocks | Warehouse Parquet/metadata objects exist | Check disk/service health; retain warehouse and catalog state |
| Iceberg + REST catalog | Table snapshots and registrations above object files | Sink commits and warehouse locations | StarRocks external catalog | Fifteen report tables can be listed/queried | Restore service/registration access; follow catalog migration notes |
| StarRocks FE/BE | Query Raw and serve transformed tables over SQL | External Raw plus dbt SQL | dbt and report clients | Raw queries and native Gold queries succeed | Check FE/BE readiness and external catalog before rebuilding |
| dbt-starrocks | Versioned SQL and executable quality contracts | Raw relations via StarRocks | Eight Silver models and one Gold model | Nine models and 32 tests pass | Inspect named failed model/test and correct the cause |
| Airflow 2.10.5 | Recurring transformation and run history | Five-minute schedule and dbt project | StarRocks report refresh | Actual scheduled run and failure probes in evidence | Use stage logs/recovery guide; pause/drain before direct dbt work |
| Power BI (optional) | Manual analyst-facing visualization | Native Gold over MySQL protocol | Desktop report | Separate driver/query notes; final UI refresh not established by cleanup | Demonstrate the same Gold SQL directly |

Versions above come from repository configuration and recorded runs, not a claim
that every image is pinned. Current Compose and dbt configuration are the source
of truth: [Compose](../../infra/docker-compose/docker-compose.yml),
[dbt project](../../dbt/dbt_project.yml), [DAG](../../infra/airflow/dags/mbs_dbt_silver_gold.py).

## Storage and modeling contracts

Raw preserves the Debezium envelope (`op`, `before`, `after`, `source`, `ts_ms`)
append-only. A SQL Server delete remains an audit event; it does not physically
remove prior Raw rows. The fifteen mappings are defined by
[Raw sources](../../dbt/models/raw/sources.yml) and
[connector registration](../../scripts/connectors/register_iceberg_day3.ps1).
Extra historical tables in a local catalog are not required report sources.

Fourteen keyed sources use [current_cdc_rows](../../dbt/macros/current_cdc_rows.sql).
Rank all snapshot/create/update/delete events by source position, retain one
latest version, then exclude a latest delete. Replays at the same immutable
coordinates do not create extra current entities. Separate status/log IDs remain
separate history rows. The active keyless assignment source remains an exception.
See the [full contracts and assumptions](02_schema_contracts.md).

Silver's physical lead key is `(source_table, customer_id)`, so movement or overlap
between active/archive tables does not imply a globally unique business lead.
[Gold SQL](../../dbt/models/gold/gold_daily_operations_report.sql) joins lead,
assignment, status, pincode, campaign and user data, applies report labels/mobile
exclusions and a date window starting at month start two months earlier. It is a
current report snapshot, not a status-event fact table or SCD Type 2 model.

The report's Gold table is native StarRocks storage, not a Gold Iceberg table.
The REST catalog's SQLite state, MinIO files, Kafka logs and native serving tables
all have distinct persistence needs. The [catalog](../decisions/006_local_catalog_and_probe_memory.md)
and [Kafka storage](../decisions/007_kafka_log_storage.md) decisions document existing
installation migration considerations.

## Scheduling, quality and scope

The single task runs `dbt run` then `dbt test`, with zero automatic retries, no
skip exit code, one active DAG run and a ten-minute DAG timeout. Stage logs name
build/test success or the original failure status. Tests run after publication;
there is no atomic swap or rollback. Direct builds must not overlap scheduled
builds. [Recovery procedure](../runbooks/03_airflow_failures.md).

The [six new quality tests](../runbooks/02_poc_execution.md#targeted-report-quality-checks)
check physical lead grain, filtered Gold membership/multiplicity, optional-agent
relationships and three required labels. Existing tests cover other selected
keys and accepted labels; the CDC fixture covers source-order/delete cases.

The current synthetic sample uses Debezium `snapshot.mode=initial`. Historical
[bulk export/cutover planning](../decisions/004_initial_bulk_load_cdc_cutover.md)
is not an implemented or benchmarked large-source ingestion path. The legacy
PyIceberg writer targets the earlier smoke dataset, not a verified replacement
for the fifteen-table report path; Spark is not deployed as a fallback.

No chatbot/LLM, new monitoring service, HA/DR or production IAM is added. Optional
BI, EC2 and future public-demo work remain separate from this local project.
