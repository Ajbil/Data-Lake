# Failure Tests Runbook

## Purpose

Validate operational behavior under five required failure scenarios.

## Scenario 1: Stop Kafka Connect for 10 Minutes

Why: Kafka Connect sits between Kafka and Iceberg. This test proves Kafka buffering and sink recovery.

Previous stage: Kafka retains Debezium events.

Next stage: Iceberg sink should resume Raw writes.

Proof:

- Stop Kafka Connect.
- Insert tagged rows into SQL Server.
- Confirm Kafka offsets advance while sink is down.
- Restart Kafka Connect after 10 minutes.
- Confirm Iceberg Raw catches up.
- Record lag and recovery time.

POC command:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\failure\connect_pause.ps1 -PauseSeconds 600
```

## Scenario 2: Simulate CDC Retention Exceeded

Why: SQL Server CDC retention is a hard operational dependency for Debezium recovery.

Previous stage: SQL Server CDC jobs retain changes.

Next stage: Debezium reads retained CDC windows.

Proof:

- Document 7-day retention.
- Simulate connector outage or retention truncation safely.
- Confirm failure mode and re-snapshot/recovery path.
- Capture DBA questions.

Automation status: manual/risk-gated only.

Do not lower or truncate CDC retention in the shared POC without DBA approval. For local-only destructive testing, capture a database snapshot/backup first, then intentionally stop Debezium past the configured retention window or reduce retention in an isolated copy. Expected recovery path is either connector re-snapshot or DBA-assisted LSN recovery.

## Scenario 3: Add New Column to `agents`

Why: Schema evolution is unavoidable in source systems.

Previous stage: SQL Server DDL changes.

Next stage: Debezium, Schema Registry, Iceberg, StarRocks, and dbt must respond predictably.

Proof:

- Add a non-PII nullable column to `dbo.agents`.
- Insert/update a row with the new column.
- Confirm Debezium emits the changed schema/event.
- Confirm Schema Registry behavior.
- Confirm Raw ingestion accepts or clearly fails.
- Document dbt changes required.

POC command:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\failure\schema_change_agents.ps1
```

## Scenario 4: Kill StarRocks BE Mid-Query

Why: StarRocks is the serving layer for dbt and PowerBI.

Previous stage: Iceberg data remains intact in MinIO.

Next stage: StarRocks query consumers should see a clear failure and recover after BE restart.

Proof:

- Run a representative query.
- Stop or kill StarRocks BE during execution.
- Capture client error and logs.
- Restart BE.
- Confirm query succeeds again.

POC command:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\failure\starrocks_be_restart.ps1 -DownSeconds 30
```

## Scenario 5: Fill MinIO Disk or Simulate Low Space

Why: Object storage health is central to Iceberg writes and metadata commits.

Previous stage: Kafka Connect or Spark writer commits files.

Next stage: Iceberg metadata and StarRocks reads depend on successful writes.

Proof:

- Prefer safe low-space simulation over actually exhausting host disk.
- Trigger or mimic write failure.
- Confirm sink error behavior.
- Confirm Kafka retains unwritten events.
- Remove simulation.
- Confirm recovery and duplicate risk.

Automation status: manual/risk-gated only.

Do not fill the host disk on a shared developer machine. Prefer an isolated Docker volume with a hard quota or a dedicated disposable VM. Stop the simulation as soon as Kafka Connect or Iceberg reports write failure, then restore capacity and confirm the sink resumes from Kafka offsets without data loss.

## Safe Combined Command

The following command runs only the safe, non-destructive scenarios:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1 failure:day6-safe
```

It covers:

- Kafka Connect pause/restart.
- Nullable `agents` schema-change probe.
- StarRocks BE restart.

It intentionally does not run:

- CDC retention truncation.
- MinIO/object-storage low-space simulation.

## Result Template

- Start time.
- Steps.
- Expected behavior.
- Actual behavior.
- Recovery time.
- Data loss or duplicate risk.
- Screenshot/log evidence.
- Follow-up risk or decision.
