# Decision 003: StarRocks and dbt Serving Layer

## Status

Accepted for Day 4 POC.

## Decision

Use StarRocks FE/BE as the SQL serving layer and `dbt-starrocks` for Silver and Gold transformations.

## Why This Is Chosen

StarRocks gives the POC a fast MySQL-compatible query endpoint for engineers, dbt, and PowerBI. It can read Iceberg Raw tables through the Iceberg REST catalog, so MinIO remains the table storage layer while StarRocks becomes the interactive SQL layer.

dbt is chosen because Silver/Gold transformations need to be versioned, reviewable, testable SQL rather than ad hoc dashboard logic.

## Previous Technology

StarRocks reads Raw Iceberg tables from:

- Iceberg REST catalog at `http://iceberg-rest:8181`.
- MinIO bucket `lakehouse`.
- Raw Kafka Connect sink tables for the DSB Daily Operations Report source tables.

## Next Technology

PowerBI will connect to StarRocks through the MySQL protocol and query the Gold model, especially `analytics.gold_daily_operations_report`.

Airflow will later run the dbt command every 5 minutes.

## What Proves It Works

- `SHOW CATALOGS` lists `iceberg_catalog`.
- `SHOW DATABASES FROM iceberg_catalog` lists `raw`.
- `SELECT COUNT(*)` over Raw Iceberg tables succeeds from StarRocks.
- `dbt run` builds the Daily Operations Report Silver models and `gold_daily_operations_report`.
- `dbt test` passes not-null, uniqueness, accepted-value, and relationship tests.

## Fallback

If StarRocks cannot reliably read Iceberg in the client environment, escalate before Day 5. The least disruptive fallback is to keep Iceberg Raw unchanged and evaluate either:

- Spark SQL or Trino as the Iceberg query layer for dbt and BI.
- StarRocks native tables loaded from Iceberg snapshots if external catalog query support blocks the POC.
