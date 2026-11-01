# Decision 002: Iceberg Sink First, Spark Structured Streaming Fallback

## Status

Accepted for Day 3 POC execution.

Current status: Kafka Connect is the verified fifteen-table report ingestion
path. The legacy PyIceberg writer below targets the earlier two-table smoke
dataset and is not a tested drop-in for this report. Spark is a historical
alternative, not a deployed service. See the [current architecture](../architecture/01_end_to_end_flow.md).

## Context

Kafka Connect Iceberg sink keeps ingestion declarative and visible through Kafka Connect. Connector maturity can still vary by image, version, Avro handling, envelope shape, and schema evolution behavior.

## Decision

Attempt Kafka Connect Iceberg sink first. If it blocks Day 3 or threatens Day 4, escalate and switch Raw ingestion to a controlled writer path.

For the current local POC, the base Kafka Connect image exposes Debezium source connectors and the Debezium JDBC sink, but not an Iceberg sink connector. The POC now installs the Apache Iceberg Kafka Connect sink plugin into the mounted plugin directory. The small PyIceberg writer remains as the fallback. Spark Structured Streaming remains the stronger production-style fallback if we need distributed continuous writes.

## Why This Choice

Kafka Connect is simpler if it works. A controlled writer is safer when custom mapping, envelope preservation, checkpointing, or commit behavior needs more control.

## Pipeline Connection

Previous technology: Kafka topics containing Debezium CDC events.

Next technology: Iceberg Raw tables on MinIO, then StarRocks and dbt.

## Escalation Triggers

- Connector cannot preserve required Debezium envelope fields.
- Avro/Schema Registry integration blocks writes.
- Schema evolution repeatedly fails tasks.
- Iceberg commits are unstable or unusable.
- Connector troubleshooting consumes more than half a POC day.

## Fallback Contract

The fallback must preserve:

- Append-only CDC rows.
- Debezium `op`, `before`, `after`, source metadata, Kafka metadata, and ingestion timestamp.
- Iceberg tables in the same MinIO warehouse.
- StarRocks readability through the external Iceberg catalog.

## Day 3 Result

- Preferred sink plugin implemented through [pom.xml](../../infra/kafka-connect/plugins/iceberg-sink/pom.xml) and [day3_iceberg_sink_plugin.ps1](../../scripts/bootstrap/day3_iceberg_sink_plugin.ps1).
- Fallback writer implemented in [write_raw_iceberg_day3.py](../../scripts/lake/write_raw_iceberg_day3.py).
- Raw namespace: `raw`.
- Kafka Connect sink tables: `raw.agents_cdc_connect` and `raw.kyc_completions_cdc_connect`.
- Fallback writer tables: `raw.agents_cdc` and `raw.kyc_completions_cdc`.
- Physical files: `s3://lakehouse/warehouse/raw/<table>/data` and `s3://lakehouse/warehouse/raw/<table>/metadata` in MinIO.
- Checkpoint: `.runtime/day3_offsets.json`, ignored from Git.

This is acceptable for the POC because it proves the table/storage contract and preserves the Debezium envelope. The sink connector is now the preferred path; the fallback remains available if connector maturity or schema handling blocks later milestones.
