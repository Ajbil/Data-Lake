# Day 04 StarRocks Iceberg

## Goal

Run StarRocks FE/BE and query Raw Iceberg tables through an external Iceberg catalog.

## Why This Matters

StarRocks is the SQL serving layer that connects Iceberg data to dbt and PowerBI.

## Commands or Actions

- Started StarRocks FE/BE through Docker Compose as `mbs-starrocks-fe` and `mbs-starrocks-be`.
- Created `iceberg_catalog` with [infra/starrocks/catalogs/create_iceberg_catalog.sql](C:\Users\caw-dev\Desktop\mbs\infra\starrocks\catalogs\create_iceberg_catalog.sql).
- Verified with:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1 bootstrap:starrocks
powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1 health:starrocks
```

## Evidence Captured

- FE and BE running.
- External Iceberg catalog configured.
- `SHOW CATALOGS` works.
- `SHOW DATABASES` and `SHOW TABLES` work.
- `SELECT COUNT(*)` over Raw succeeds:
  - `iceberg_catalog.raw.agents_cdc_connect`: 50 rows.
  - `iceberg_catalog.raw.kyc_completions_cdc_connect`: 18 rows.

## Observations

- StarRocks reads Iceberg structs cleanly with dot access, for example `after.agent_id` and `source.ts_ms`.
- StarRocks FE exposes MySQL protocol on host port `9030`; this becomes the dbt and PowerBI entry point.
- The external Iceberg catalog keeps Raw data in MinIO while StarRocks handles SQL scans and downstream serving.

## Issues and Follow-Ups

- Cold vs warm query timing still needs formal capture during Day 6 latency testing.
- Current Raw sink tables do not yet expose every desired Kafka metadata field; Silver currently deduplicates by Debezium source time and envelope time.
