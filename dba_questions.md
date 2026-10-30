# DBA Questions

## CDC and Retention

- Is 7-day CDC retention acceptable for the source database operationally?
- Who owns CDC cleanup job monitoring?
- What is the recovery path if Debezium falls behind retention?
- Can CDC be enabled before the initial bulk export starts?
- Can the DBA provide the export start LSN from `sys.fn_cdc_get_max_lsn()` and the corresponding UTC timestamp?
- Can CDC retention cover the full export duration, validation duration, and recovery buffer?

## SQL Server Agent

- Is SQL Server Agent available and monitored in the target environment?
- Are CDC capture and cleanup jobs allowed on the source host?

## Schema Changes

- What is the process for DDL changes on CDC-enabled tables?
- Are nullable additive columns allowed without coordination?
- How are breaking changes communicated?
- Can schema changes be frozen during initial bulk export and CDC cutover?

## Load and Performance

- What write volume should this POC approximate beyond the 10 rows/sec Day 6 test?
- Are there source database load windows or throttling requirements?
- What are the row counts and approximate data sizes for each in-scope source table?
- What is the average and peak insert/update/delete volume per table?
- What bulk export method is approved: backup/restore, BCP, SSIS, Azure Data Factory, AWS DMS, or file extract?
- What extraction throughput is acceptable for UAT and production?
- Is a transactionally consistent snapshot required, or is table-level reconciliation acceptable?

## Initial Load Validation

- What row counts, checksums, or sampled primary keys should be used to validate the initial load?
- Which business totals should reconcile between source and Gold?
- Who signs off the source-to-lake initial load reconciliation?

## Data Governance

- Which columns are considered PII in production?
- Are synthetic references acceptable for demos?
