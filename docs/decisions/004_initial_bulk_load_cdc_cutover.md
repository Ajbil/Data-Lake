# Decision 004: Bulk Initial Load with Debezium CDC Cutover

## Status

Recommended for production-scale client data; not implemented in the current POC scripts.

## Context

The current POC proves the live path with small seeded tables. Client initial data can be much larger, and pushing the full historical dataset through a Debezium initial snapshot may take too long or place avoidable load on SQL Server, Kafka, and Iceberg.

## Decision

For large source tables, prefer a controlled bulk initial load followed by Debezium CDC cutover:

```text
Enable CDC -> record export start LSN/time -> bulk export existing rows
-> load snapshot rows into Raw Iceberg -> start Debezium without full snapshot
-> capture changes after the cutover point -> build Silver/Gold
```

Debezium remains the ongoing CDC mechanism. The bulk export is only for the historical/base load.

## Why This Choice

Bulk export gives more control over source load, throughput, retries, and validation for large tables. CDC still captures inserts, updates, and deletes that happen during or after the export, as long as CDC retention covers the full backfill and validation window.

## Pipeline Connection

Previous technology: SQL Server tables with CDC enabled and a recorded log sequence number (LSN) or export timestamp.

Next technology: Raw Iceberg contains both snapshot-shaped rows and Debezium CDC rows. Silver uses primary key plus source ordering to keep the latest state, and Gold is built from Silver.

## Raw Contract

Snapshot rows should be written in the same logical shape as CDC rows where practical:

- `op = 'r'` or an explicit snapshot operation marker.
- `before = null`.
- `after = full source row`.
- Source metadata includes `snapshot_batch_id`, export start/end time, and the recorded LSN when available.
- Raw remains append-only.

This lets Silver use one deduplication path across the initial snapshot and later CDC events.

## Cutover Requirements

- CDC must be enabled before the bulk export starts.
- Record `sys.fn_cdc_get_max_lsn()` and `SYSUTCDATETIME()` at export start.
- CDC retention must exceed export duration, validation time, and recovery buffer.
- Debezium should be configured for no-data/schema-only snapshot mode for the CDC phase so it does not re-snapshot the full table.
- Schema changes should be frozen or tightly coordinated during the initial load window.

## What Proves It Works

- Source export row counts match loaded Raw snapshot counts.
- CDC events after the recorded cutover point appear in Kafka and Raw Iceberg.
- Silver row counts and sampled primary keys match the expected latest source state.
- Gold business aggregates reconcile with source-approved control totals.
- A tagged change made during or after export is visible in Gold within the agreed SLA.

## Fallback

If bulk export cannot be approved, use Debezium initial snapshot with explicit source-load windows and throughput monitoring. If CDC retention cannot cover the export window, pause writes during export or require a fresh export/cutover.
