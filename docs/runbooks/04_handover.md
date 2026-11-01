# Project walkthrough and handover

Use [the README](../../README.md) to set up the local synthetic demo and
[the evidence index](../../evidence/README.md) to review recorded results. This
walkthrough focuses on the data engineering path; a website or BI UI is optional.

## Before a demonstration

Run the existing `ps`, `health:iceberg` and `health:starrocks` commands from the
README. Confirm source plus fifteen sink tasks are healthy and Raw is queryable.
Use the [Airflow guide](03_airflow_failures.md) to inspect the latest report run.
If the pipeline is unavailable, present the dated committed evidence and explain
that it is a recorded run rather than a live result.

Prepare a SQL client for `localhost:9030`, database `analytics`. Optional Kafka UI
and Airflow UI can be started as described in the README, but their presence is
not necessary for the walkthrough. Use synthetic data only.

## Five-to-ten-minute walkthrough

| Time | Show | Explain |
| --- | --- | --- |
| 0-1 min | README data-flow diagram | Capture operational changes, preserve Raw history, and produce a report with repeatable SQL |
| 1-2 min | Raw source definitions and baseline counts | Fifteen sources, Avro contracts and append-only CDC; source rows and Raw events have different counts |
| 2-4 min | Shared CDC macro and before/after delete evidence | Rank by SQL Server source position, include deletes in ranking, then filter latest deletes; keep the keyless exception explicit |
| 4-6 min | Silver/Gold SQL and quality evidence | Physical lead grain, joins, report eligibility, relationships and failing bad-data fixtures |
| 6-8 min | Scheduled run metadata and failure log excerpts | Nine models, 32 tests, stage/exit visibility; distinguish a scheduled run from a manual verification |
| 8-10 min | Gold SQL query and limitations | Query the report, then explain full rebuilds, non-atomic publication and what remains unproven |

Example read-only report query:

```sql
SELECT lead_source_table, record_type, serviceable_pincode, COUNT(*) AS lead_count
FROM analytics.gold_daily_operations_report
GROUP BY lead_source_table, record_type, serviceable_pincode
ORDER BY lead_source_table, record_type, serviceable_pincode;
```

For a live insert/update/delete demonstration, run `test:cdc` separately and allow
more time; the recorded run took about 11 minutes 40 seconds including waiting
for an active DAG run. The command creates/cleans its own synthetic lead. Do not
manually edit preserved demonstration rows or run sample bootstrap during a demo.
Details: [CDC smoke check](02_poc_execution.md#one-command-cdc-smoke-check).

## Interview explanation

A concise explanation supported by the repository is:

> I built a local CDC-to-report pipeline using SQL Server, Debezium, Kafka,
> Iceberg/MinIO, StarRocks, dbt and Airflow. I corrected keyed update/delete
> handling using source positions, added repeatable lifecycle and data-quality
> checks, and verified a normal scheduled report run plus clear failure reporting.
> Raw stays append-only; the current serving models are native StarRocks tables.

Useful follow-up topics are why timestamps alone can select the wrong CDC row,
why a latest delete must be considered before filtering, why Raw/current/report
counts differ, and why a five-minute schedule is not a latency guarantee.

Avoid claiming exactly-once end-to-end processing, SCD Type 2, production-scale
benchmarks, Gold-on-Iceberg storage, atomic publication or a deployed AI app.
Those are not established by the current evidence.

## Handover checklist

- Follow the current Windows README; keep `.env` local and match the demo source contract.
- Read [project risks](../../project_risks.md) and [lessons learned](../../lessons_learned.md).
- Review [evidence](../../evidence/README.md) and the linked dated notes rather than relying on screenshots outside Git.
- Inspect the latest scheduled run and its complete model/test outcome.
- Use the [failure/recovery guide](03_airflow_failures.md) before attempting repairs.
- Keep the original architecture image and any existing `data_lake` folder untouched.

The older [EC2 guide](01_ec2_setup.md), milestone notes and external-source
[DBA questions](../../dba_questions.md) are context, not additional steps required
for this personal project. Power BI UI refresh and Linux/EC2 operation have not
been revalidated by the six-step cleanup.
