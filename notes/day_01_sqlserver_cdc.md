# Day 01 SQL Server CDC

## Goal

Create `mbs_poc`, define source tables, enable CDC, and set retention to 7 days.

## Why This Matters

SQL Server CDC is the first reliable source of row-level changes. Debezium depends on this layer being healthy before Kafka can receive events.

## Commands or Actions

- Started `mcr.microsoft.com/mssql/server:2019-latest` through Docker Compose.
- Ran `scripts/bootstrap/day1_sqlserver.ps1`.
- Created database `mbs_poc`.
- Created `dbo.agents` and `dbo.kyc_completions`.
- Seeded 50 synthetic agents and 12 synthetic KYC completions.
- Enabled CDC on the database and both tables.
- Set cleanup retention to 10080 minutes, equivalent to 7 days.
- Ran `scripts/health/day1_verify_sqlserver.ps1`.

## Evidence Captured

- Database `mbs_poc` exists and `is_cdc_enabled = 1`.
- `dbo.agents` and `dbo.kyc_completions` both report `is_tracked_by_cdc = 1`.
- CDC cleanup job retention is `10080`; capture job exists with polling interval `5`.
- Seed count: 50 agents.
- Agent bank distribution: `AXIS=13`, `HDFC=12`, `ICICI=13`, `SBI=12`.
- Seed count: 12 KYC completions before verification insert.
- Verification insert with `event_tag = day1-cdc-verification` appeared in `cdc.fn_cdc_get_all_changes_dbo_kyc_completions`.

## Observations

- SQL Server Agent started inside the container via `MSSQL_AGENT_ENABLED=true`.
- Bootstrap initially printed SQL Server Agent messages when CDC jobs were already running or pending. The scripts were adjusted to tolerate those start/stop states more cleanly for future reruns.
- The verification script inserted one additional KYC row, so the table has at least 13 rows after verification.

## Issues and Follow-Ups

- Day 2 should register Debezium against these CDC-enabled tables.
- If the bootstrap is rerun, it now disables CDC before dropping the two source tables.
