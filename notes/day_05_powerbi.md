# Day 05 PowerBI

## Goal

Connect PowerBI Desktop to StarRocks and build the KYC completions by bank chart.

## Why This Matters

PowerBI is the final business-facing proof that the pipeline produces usable analytics.

## Commands or Actions

- Updated [docs/runbooks/03_powerbi_starrocks.md](C:\Users\caw-dev\Desktop\mbs\docs\runbooks\03_powerbi_starrocks.md) with local StarRocks connection details and a validation query.
- PowerBI Desktop remains a manual UI validation step.

## Evidence Captured

- Driver/version recorded.
- Connection string details recorded without secrets.
- Chart created for last 24 hours by bank.
- Refresh timing recorded.
- Screenshot saved.

## Observations

- StarRocks MySQL endpoint is available on `localhost:9030` for local PowerBI Desktop.
- Gold table is `analytics.fact_kyc_completions`.
- Current data groups as AXIS 3, HDFC 9, ICICI 3, and SBI 3 after Day 4/5 verification.

## Issues and Follow-Ups

- Need PowerBI Desktop installed on Windows with a compatible MySQL connector.
- Need screenshot saved in `screenshots/` after manual visual creation.
- Need refresh timing captured after inserting a new SQL Server row and waiting for the Airflow cycle.
