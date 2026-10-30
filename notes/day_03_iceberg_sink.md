# Day 03 Iceberg Sink

## Goal

Write append-only Debezium CDC events from Kafka to Raw Iceberg tables.

## Why This Matters

The Raw layer is the audit-preserving bridge between event capture and analytics SQL.

## Commands or Actions

- Checked Kafka Connect plugins at `http://localhost:8083/connector-plugins`.
- Confirmed the active Connect image does not include an Iceberg sink connector.
- Added Apache Iceberg Kafka Connect sink plugin dependencies under `infra/kafka-connect/plugins/iceberg-sink`.
- Restarted Kafka Connect and confirmed `org.apache.iceberg.connect.IcebergSinkConnector` version `1.8.1`.
- Registered two Iceberg sink connectors, one for `agents` and one for `kyc_completions`.
- Corrected Iceberg REST MinIO config from `CATALOG_S3_PATH_STYLE_ACCESS` to `CATALOG_S3_PATH__STYLE__ACCESS` so S3 path-style addressing works.
- Added a Day 3 Python writer fallback using `confluent-kafka` and `pyiceberg`.
- Added `plugin:iceberg`, `register:day3`, `health:iceberg`, `bootstrap:day3`, and `health:day3` to the project command runner.

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1 bootstrap:day3
powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1 health:day3
powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1 plugin:iceberg
docker compose --env-file .env -f infra/docker-compose/docker-compose.yml restart kafka-connect
powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1 register:day3
powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1 health:iceberg
```

## Evidence Captured

- Kafka Connect Iceberg sink was added to the current runtime and verified.
- Sink connector tables `raw.agents_cdc_connect` and `raw.kyc_completions_cdc_connect` were created and populated.
- Raw `raw.agents_cdc` and `raw.kyc_completions_cdc` tables were created.
- Parquet and Iceberg metadata files are visible in MinIO.
- `health:day3` inserts a tagged SQL row and verifies that the tag appears in Raw Iceberg.
- Small-file behavior observed: each writer run commits at least one new Parquet file per table with new rows.
- Schema mismatch handling: the writer uses an explicit PyArrow schema matching the Iceberg schema, with the full Debezium envelope stored as JSON columns.

## Fallback Watch

The base connector path initially blocked because the Kafka Connect runtime had no Iceberg sink plugin. The plugin is now installed. Keep the PyIceberg fallback and Spark Structured Streaming escalation path available if connector schema handling or commit behavior blocks later milestones.

## Observations

- First verified run created the Raw namespace and both Raw tables.
- First writer catch-up appended 50 `agents` snapshot rows and 16 `kyc_completions` rows.
- Repeat run inserted `day3-iceberg-20260504140428` and appended exactly 1 new row to `raw.kyc_completions_cdc`.
- Kafka Connect sink verification inserted `iceberg-sink-20260504151511`.
- Kafka Connect sink table counts after verification: `raw.agents_cdc_connect` = 50, `raw.kyc_completions_cdc_connect` = 18.
- MinIO object evidence included:
- `warehouse/raw/agents_cdc/data/*.parquet`
- `warehouse/raw/agents_cdc/metadata/*.metadata.json`
- `warehouse/raw/kyc_completions_cdc/data/*.parquet`
- `warehouse/raw/kyc_completions_cdc/metadata/*.metadata.json`

## Issues and Follow-Ups

- Decide whether Day 4 StarRocks should read these JSON-preserved Raw tables directly or whether we create a more typed Raw projection first.
- Decide whether to keep the Maven-installed mounted plugin path, or build a custom Kafka Connect image for non-local environments.
- Current Raw writer is batch-style and manually invoked by `health:day3`; a production deployment would run it as a service/job with operational monitoring.
