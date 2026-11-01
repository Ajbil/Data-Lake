# Day 04 dbt

## Goal

Create dbt Raw source definitions, Silver latest-state models, and Gold `fact_kyc_completions`.

## Why This Matters

dbt turns auditable CDC into business-ready analytics tables.

## Commands or Actions

- Installed pinned `dbt-starrocks==1.11.0` from [requirements-day4.txt](../requirements-day4.txt).
- Created dbt project/profile files under [dbt](../dbt).
- Built and tested models with:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1 bootstrap:dbt
powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1 run:dbt
powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1 health:dbt
```

## Evidence Captured

- Raw sources defined.
- Silver models deduplicate latest state per primary key.
- Gold joins KYC completions with agent metadata.
- `dbt run` succeeded for 3 models.
- `dbt test` passed 14 tests.
- Final counts:
  - `analytics.silver_agents`: 50 rows.
  - `analytics.silver_kyc_completions`: 18 rows.
  - `analytics.fact_kyc_completions`: 18 rows.
  - Gold bank split: AXIS 3, HDFC 9, ICICI 3, SBI 3.

## Observations

- The first dbt configuration created `analytics_analytics`; this was caused by dbt schema naming behavior and was removed after project config was corrected.
- Seed data includes `REJECTED` KYC status, so accepted-value tests include `COMPLETED`, `PENDING`, `REJECTED`, and `FAILED`.
- Silver currently filters `op in ('r', 'c', 'u')` and ignores deletes because delete semantics need a deliberate business choice.

## Issues and Follow-Ups

- Day 5 Airflow should call the same dbt run/test logic every 5 minutes.
- Decide whether Silver/Gold should remain StarRocks-managed internal tables for the POC or later be written back as Iceberg tables.
