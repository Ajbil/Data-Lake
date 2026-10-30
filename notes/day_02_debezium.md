# Day 02 Debezium

## Goal

Register the Debezium SQL Server connector for `dbo.agents` and `dbo.kyc_completions`.

## Why This Matters

Debezium bridges SQL Server CDC into Kafka topics. Its output feeds Schema Registry and the Raw Iceberg sink.

## Commands or Actions

- Added `infra/kafka-connect/connectors/debezium-sqlserver-mbs-poc.template.json`.
- Added `scripts/bootstrap/day2_sqlserver_debezium_user.ps1`.
- Added `scripts/connectors/register_debezium_day2.ps1`.
- Added `scripts/health/day2_verify_pipeline.ps1`.
- Created SQL login `mbs_debezium_user`.
- Granted `db_datareader`, `VIEW DATABASE STATE`, `SELECT` on `cdc`, and `VIEW SERVER STATE`.
- Registered connector `mbs-sqlserver-cdc` through Kafka Connect REST API.
- Inserted tagged verification row through Day 2 health check.

## Evidence Captured

- Connector status is `RUNNING`; task `0` is `RUNNING`.
- Debezium completed initial snapshot:
  - `dbo.agents`: 50 records.
  - `dbo.kyc_completions`: 13 records at snapshot time.
- Generated Kafka topics:
  - `mbs_poc`.
  - `mbs_poc.mbs_poc.dbo.agents`.
  - `mbs_poc.mbs_poc.dbo.kyc_completions`.
  - `schemahistory.mbs_poc`.
- Verification insert tag: `day2-debezium-20260501123556`.
- The tagged row appeared in topic `mbs_poc.mbs_poc.dbo.kyc_completions`.
- Observed CDC latency from Debezium source timestamp to connector emit timestamp was about 3.6 seconds for the tagged verification row.
- The Kafka message preserved the Debezium envelope with `before`, `after`, `source`, `op`, `ts_ms`, `ts_us`, and `ts_ns`.

## Observations

- Snapshot mode is `initial`, so Debezium first emitted existing table rows, then switched to streaming.
- The verification row arrived with `op = c`, meaning create/insert.
- Kafka Connect now uses Confluent Avro converters for both key and value serialization.
- Schema Registry is running and now has registered subjects for the KYC CDC topic.
- The Debezium image does not include the Confluent Avro converter by default, so the POC installs it under `infra/kafka-connect/plugins/avro-converter`.
- Kafka console output is binary after this change. Kafka UI with Schema Registry, or an Avro-aware console consumer, should be used for readable inspection.

## Issues and Follow-Ups

- For a clean UAT/prod deployment, avoid mixing JSON and Avro messages in the same topic. Use empty topics or a fresh topic prefix when migrating serialization format.
- Kafka UI can show the CDC topics and messages now.
- Schema change behavior still needs to be tested with an additive column scenario on Day 6.
