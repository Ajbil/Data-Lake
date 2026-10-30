# Day 08 Initial Bulk Load and CDC Cutover

## Goal

Document the production-scale approach for very large client source tables.

## Decision

Use bulk initial load plus Debezium CDC cutover when table size makes a Debezium full initial snapshot risky or slow.

## Flow

```text
Enable CDC -> record export start LSN/time -> bulk export existing rows
-> load snapshot rows into Raw Iceberg -> start Debezium for ongoing CDC
-> build Silver/Gold once -> run incremental scheduled transforms
```

## Key Gotchas

- CDC must be enabled before export starts, otherwise changes during export can be missed.
- CDC retention must cover export, validation, and recovery time.
- Snapshot rows and CDC rows should share a compatible Raw contract so Silver can deduplicate by primary key and source order.
- Schema changes should be frozen or tightly coordinated during the initial load window.
- The current POC documents this path but does not yet implement the bulk loader or incremental dbt models.
