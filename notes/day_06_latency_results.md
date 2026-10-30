# Day 06 Latency Results

## Goal

Run loader at about 10 rows/sec for 30 minutes and trace tagged rows through every stage.

## Why This Matters

The main acceptance target is under 5 minutes from SQL Server insert to PowerBI visibility.

## Timing Capture

| Event tag | SQL insert | Kafka visible | Iceberg Raw | Silver after dbt | Gold after dbt | PowerBI refresh | Total |
| --- | --- | --- | --- | --- | --- | --- | --- |
| day6-smoke-latency | 0.182s | 11.029s | 183.111s | 209.221s | 209.383s | Pending manual refresh | 209.384s to Gold |

## Commands

Sustained loader:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1 load:day6
```

Default loader behavior:

- Inserts KYC rows at 10 rows/sec.
- Runs for 30 minutes.
- Uses a generated `day6-load-yyyyMMddHHmmss` batch tag.

Tagged latency probe:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1 latency:day6
```

The latency probe inserts one tagged row and records these checkpoints:

- SQL Server insert.
- Kafka topic visibility.
- Iceberg Raw visibility through StarRocks.
- Airflow dbt DAG completion.
- Silver visibility.
- Gold visibility.
- PowerBI refresh pending manual validation.

CSV evidence is written to `screenshots/<event-tag>-latency.csv`.

## Escalation Rule

If end-to-end latency is over 10 minutes, escalate immediately.

## Observations

- PowerBI refresh remains manual because PowerBI Desktop is outside the Docker stack.
- The first Airflow/dbt run after a cold Docker restart may be slower because dbt parses the project and StarRocks loads Iceberg metadata.
- Smoke latency result used `TransformMode local` to force the dbt cycle immediately instead of waiting for the next 5-minute Airflow schedule.
- Smoke result was under the 5-minute SQL-to-Gold target: about 3 minutes 29 seconds.
- Iceberg Raw visibility was the longest checkpoint in the smoke run at about 183 seconds, likely tied to the Kafka Connect Iceberg sink commit interval plus cold metadata checks.
- After smoke tests, Gold contained 21 KYC rows: AXIS 3, HDFC 12, ICICI 3, SBI 3.

## Issues and Follow-Ups

- Run the full 30-minute loader on the target POC machine and attach the generated latency CSV.
- If total SQL-to-Gold latency is over 10 minutes, escalate immediately.
- Run the same latency probe with `-TransformMode airflow` during formal Day 6 evidence capture to include Airflow scheduling/orchestration time.
