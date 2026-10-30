# Day 9: Daily Operations Report Migration

## What Changed

- Repointed the main Debezium connector template to the DSB report table family across `EKYC_ICICI` and `EKYC_ICICI_Archived`.
- Added a reusable Kafka Connect Iceberg sink template for DSB Raw tables.
- Updated Windows and Linux registration scripts to create one Raw Iceberg sink connector per report source table.
- Replaced the active dbt models with Daily Operations Report Silver and Gold models.
- Renamed the Airflow DAG id to `mbs_daily_operations_report` while keeping the 5-minute schedule.

## Target Gold Model

`default_catalog.analytics.gold_daily_operations_report`

## Important Caveat

The client report views decrypt several base-table columns with `dbo.DecryptedData()`. Debezium captures the physical base tables, not the reporting view output. Before production hardening, the client must approve one of these paths:

- source-side decrypted/report-safe staging columns,
- downstream reuse of the decryption logic,
- or masking/excluding encrypted PII fields from lakehouse reporting.

## Validation Focus

- Debezium connector is running.
- Schema Registry subjects exist for DSB CDC topics.
- Raw Iceberg tables are present in MinIO and queryable from StarRocks.
- dbt builds all Silver models and `gold_daily_operations_report`.
- PowerBI connects to StarRocks and refreshes from the Gold model.
