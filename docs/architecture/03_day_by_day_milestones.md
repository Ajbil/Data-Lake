# Seven-Day Milestones

## Day 1: Repo, SQL Server, CDC, Kafka Foundation

Deliverables:

- Scaffold exists under `C:\Users\caw-dev\Desktop\mbs`.
- SQL Server 2019 running.
- `mbs_poc`, `agents`, and `kyc_completions` created.
- CDC enabled and verified on both tables.
- Kafka, Schema Registry, Kafka Connect, and Kafka UI running.

Proof:

- Insert row into SQL Server.
- Query SQL Server CDC change table.
- Confirm Kafka/Kafka Connect services are healthy.

Notes:

- `notes/day_01_sqlserver_cdc.md`.
- `notes/day_01_kafka_setup.md`.

## Day 2: Debezium, MinIO, Iceberg Catalog

Deliverables:

- Debezium connector registered.
- CDC events visible in Kafka UI.
- MinIO running with `lakehouse` bucket.
- Iceberg REST catalog connected to MinIO.

Proof:

- Insert row into SQL Server.
- See event in Kafka topic within 1-2 seconds.
- Confirm Iceberg catalog can reach MinIO.

Notes:

- `notes/day_02_debezium.md`.
- `notes/day_02_minio_iceberg_catalog.md`.

## Day 3: Kafka Connect Iceberg Sink

Deliverables:

- Iceberg sink connector configured.
- Raw append-only Iceberg tables created.
- Raw CDC events written as Parquet/metadata files.
- Connector status checks scripted.

Proof:

- Insert rows into SQL Server.
- See Kafka events.
- See Iceberg/Parquet files in MinIO within about 1 minute.

Notes:

- `notes/day_03_iceberg_sink.md`.

## Day 4: StarRocks + dbt Silver/Gold

Deliverables:

- StarRocks FE/BE running.
- External Iceberg catalog configured.
- StarRocks queries Raw Iceberg tables.
- dbt project created.
- Daily Operations Report Silver models and Gold `gold_daily_operations_report` built.

Proof:

- StarRocks `SELECT COUNT(*)` over Raw works.
- `dbt run` builds Silver and Gold.
- Gold joins KYC completions with agent metadata.

Notes:

- `notes/day_04_starrocks_iceberg.md`.
- `notes/day_04_dbt.md`.

## Day 5: Airflow + PowerBI

Deliverables:

- Airflow running.
- DAG scheduled every 5 minutes.
- DAG runs `dbt run`, optionally `dbt test`.
- PowerBI connects to StarRocks.
- Chart created: KYC completions by bank, last 24 hours.

Proof:

- Insert SQL Server row.
- Wait for Airflow/dbt cycle.
- Refresh PowerBI and see chart update.

Notes:

- `notes/day_05_airflow.md`.
- `notes/day_05_powerbi.md`.

## Day 6: End-to-End Timing + Failure Scenarios

Deliverables:

- Loader runs at about 10 rows/sec for 30 minutes.
- Tagged row timing captured through all stages.
- Five required failure scenarios run.

Proof:

- End-to-end target is under 5 minutes.
- If over 10 minutes, escalate immediately.

Notes:

- `notes/day_06_latency_results.md`.
- `notes/day_06_failure_tests.md`.

## Day 7: Handover, Lessons, Demo Recording

Deliverables:

- Final README clean-run instructions.
- `lessons_learned.md`.
- `dba_questions.md`.
- `project_risks.md`.
- Screenshots collected.
- 5-10 minute demo recording.
- Final 30-minute walkthrough outline.

Proof:

- Another engineer can follow README and run the POC without help.
- Final readout is ready for CAW Engineering Team.
