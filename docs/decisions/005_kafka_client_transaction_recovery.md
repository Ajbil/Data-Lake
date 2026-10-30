# Decision 005: Patch Kafka Client Transaction Shutdown

## Status

Verified for local recovery, 2026-10-29. Two full tagged tests passed; the
original waiting row was recovered into Gold. A real connector task restart
retained Kafka position 14 and resumed with an active consumer and zero lag.

## Evidence

The Debezium 2.7 worker contains `kafka-clients-3.7.0.jar`. After a transaction
timeout its Iceberg coordinator threads remain inside `KafkaProducer.close()`;
producer threads repeatedly fail to abort a pending commit. The Customer Lead
task fails with `Coordinator unexpectedly terminated`, its consumer group has
no active members, and Kafka contains rows missing from Raw. The connector-level
status alone still says RUNNING.

This matches Apache [KAFKA-16217](https://issues.apache.org/jira/browse/KAFKA-16217),
fixed in Kafka 3.7.1/3.8.0. Windows recorded a wake from sleep this morning;
sleep is a plausible timeout trigger, not a proven cause of the initial timeout.

## Decision and Dependencies

Build a local image from the existing Debezium image, pinned by digest, replacing
only its Kafka client with checksum-verified 3.7.2, a patch release in the same
3.7 series. Retain the source connector, sink plugins, broker, control topics,
consumer offsets, and storage formats. Kafka supplies events to this worker;
the worker writes Iceberg Raw for StarRocks and dbt.

The latency check must validate task states before inserting, report progress
while waiting, stop on failed tasks, and save each completed checkpoint. It must
not hide failures behind automatic restarts. A transaction timeout can still
fail a task: this patch prevents the shutdown deadlock, not laptop suspension.

## Proof and Fallback

Use a small Java probe that recreates a pending commit and closes the actual
Kafka producer. It must fail with 3.7.0 and terminate with 3.7.2. Then recover
the queued sample row, run the full tagged source-to-Gold check, and exercise
a connector restart without resetting offsets. Record results in the runbook
and dated notes. A short passing test does not establish overnight stability.

If the patched worker is incompatible, retain the old image for rollback and
investigate a supported whole-worker upgrade. Never reset Kafka offsets or
delete/recreate Kafka as recovery. Decision 006 documents the subsequent
preserved migration of the catalog into persistent storage.
