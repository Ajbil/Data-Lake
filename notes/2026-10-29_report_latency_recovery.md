# Report Latency Recovery — 2026-10-29

## Symptom and Evidence

`latency:report` inserted `CDC-LATENCY-20261029130121` in 4.027 seconds and
observed Kafka at 28.765 seconds, then timed out after 900 seconds waiting for
Raw. The Customer Lead connector said RUNNING but its task was FAILED with
`Coordinator unexpectedly terminated`. The group had no active members; its
saved position was 8 while later source records remained queued. Raw still had
8 records in yesterday's snapshot.

The worker used Kafka client 3.7.0. Coordinator threads were blocked in
`KafkaProducer.close()` and producer threads repeatedly failed to abort a pending
commit, matching KAFKA-16217. Windows recorded a wake-up at 08:43 local; this is
a possible trigger, not proof of the initial timeout's cause.

## Changes and Checks

- Built a digest-pinned Debezium image with checksum-verified Kafka client 3.7.2.
  An isolated real-producer regression reproduced the close deadlock with 3.7.0
  (still blocked at 3 seconds) and completed with 3.7.2 in 0.669 seconds.
- Added task preflight and ongoing checks, 30-second wait progress, immediate
  checkpoint CSV writes, and visible warehouse query errors. A real preflight
  rejected the FAILED task in 1.311 seconds before any insert. Mocked failed and
  healthy tasks, progress/evidence/timeout checks, and query-error propagation
  checks passed. Full execution caught and corrected a Windows PowerShell quote
  handling issue in the revised SQL helper.
- Diagnosed resource exhaustion: the Docker VM had only 169 MiB available and
  all 2 GiB of swap occupied. Stopping temporary Kafka CLI probes freed over
  2 GiB. Their inherited heaps were oversized; the latency consumer now uses
  32 MiB initial / 128 MiB maximum memory.
- Found StarRocks FE's default 8 GiB Java maximum exceeded the whole 7.6 GiB VM.
  It had reached 2.2 GiB RSS. Capped its heap at 1 GiB and Connect at 1 GiB with
  a 256 MiB initial heap. FE recovered its existing metadata and became healthy;
  its observed RSS was approximately 1.1 GiB afterward.
- Observed fresh catalog `SQLITE_BUSY` during attempted ingestion recovery.
  Stopped Connect and the scheduler, stopped the catalog, copied its SQLite
  database, passed integrity checking, and preserved all 19 table registrations.
  Restored it to `mbs-poc_iceberg-catalog-data` with one JDBC connection, WAL,
  and a 30-second busy timeout. Verified all 19 names match before/after.
  The backup and registration list remain under ignored
  `.runtime/iceberg-catalog-backup/`. Kafka and MinIO were not recreated and
  no consumer offsets were reset.
- Restored the scheduler. Kafka UI and the Airflow webserver remain stopped,
  following the user's explicit preference. With the full pipeline restored,
  VM available memory measured 1.7 GiB and memory-pressure averages approached
  zero; old swapped pages remained allocated, which alone is not active thrash.

## Integration Verification

The original waiting tag was found in Raw after recovery. Fresh full-flow tag
`CDC-LATENCY-20261029140320` reached SQL at 3.344 seconds, Kafka at 49.935 seconds,
and Raw at 51.878 seconds. Gold was visible at 288.671 seconds, with total command
time 293.279 seconds. The row matched Fresh / High-priority / Serviceable /
AG001 / Ravi Agent. The original user tag was also verified in Gold with its
agent assignment. The scheduled report run succeeded with all 9 models and
25 tests; all 17 registered sink tasks were RUNNING. The explicitly triggered
run also succeeded at 08:43:05 UTC.

A real catalog restart retained snapshot `2603381581306431442` and all 19
registrations. A second fresh tag, `CDC-LATENCY-20261029141350`, then reached SQL
at 1.063 seconds, Kafka at 42.234, Raw at 42.983, and Gold at 140.749, with total
command time 143.056 seconds. Its report details matched the expected campaign,
serviceability and agent. The scheduled report run also succeeded.
The second explicitly triggered run completed successfully at 08:50:26 UTC;
its log recorded `PASS=25 WARN=0 ERROR=0`. Subsequent scheduled runs also
succeeded, and the DAG was verified unpaused after all recovery checks.

The initial connector restart request lacked a JSON content type and returned
HTTP 415; that request did not restart it. The corrected request returned HTTP
202. The real task restart retained position 14; the consumer was active with
current offset 14, log end 14, lag 0. No offsets were reset.

Dashboard services now use an opt-in Compose profile. The Windows Airflow
bootstrap starts the scheduler without the webserver. Startup runners reject
replacement of an existing catalog that has not yet been migrated to persistent
storage. Their safe-start guard, shell syntax, and Compose profile checks were
validated. Overnight and laptop-sleep stability have not been established by
these short integration checks.

See Decisions [005](../docs/decisions/005_kafka_client_transaction_recovery.md)
and [006](../docs/decisions/006_local_catalog_and_probe_memory.md), and the
[execution runbook](../docs/runbooks/02_poc_execution.md).
