# Day 06 Failure Tests

## Goal

Run and document the five required failure scenarios.

## Required Scenarios

- Stop Kafka Connect for 10 minutes and restart.
- Simulate CDC retention exceeded/truncated CDC capture.
- Add a new column to `agents`.
- Kill StarRocks BE mid-query.
- Fill MinIO disk or simulate low-space behavior.

## Result Summary

| Scenario | Expected | Actual | Recovery time | Data risk | Follow-up |
| --- | --- | --- | --- | --- | --- |
| Kafka Connect outage | Kafka buffers; sink catches up after restart | 5-second smoke pause/restart succeeded | About 5 seconds plus restart | Low if Kafka retention holds | Run formal test with 600-second pause |
| CDC retention exceeded | Debezium fails clearly; re-snapshot/recovery needed | Manual/risk-gated only | TBD | High if retention really exceeded | DBA approval required |
| Add `agents` column | Nullable column appears in CDC Raw; dbt impact documented | Smoke script added/updated `day6_schema_probe` on `agent_id = 1` | Immediate SQL success | Low | Validate topic and Raw schema |
| Kill StarRocks BE | Query fails while BE is down, succeeds after restart | 5-second smoke stop/restart succeeded; BE returned healthy | About 5 seconds plus restart | Low; storage remains in Iceberg | Capture query/log screenshots |
| MinIO low space | Sink fails clearly; Kafka retains unwritten events | Manual/risk-gated only | TBD | Medium/high if host disk filled | Use disposable volume/VM |

## Evidence

- Safe combined command:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1 failure:day6-safe
```

- Individual commands live under [scripts/failure](C:\Users\caw-dev\Desktop\mbs\scripts\failure).
- CDC retention exceeded and MinIO low-space tests remain manual/risk-gated by design.
- Smoke command executed successfully with `-ConnectPauseSeconds 5 -StarRocksDownSeconds 5`.
- Kafka Connect and StarRocks BE were confirmed running after the smoke test.
