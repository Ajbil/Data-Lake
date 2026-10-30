# Connector Registration Recovery — 2026-10-29

## Failure

The user's `start` completed, but `health:iceberg` loaded the 1.8.1 plugin and
returned 404 for Customer Lead. The worker had already finished startup with an
empty connector list and configuration offset -1. The Kafka container had been
recreated at 10:55 UTC (16:25 IST), and only newly initialized internal topics
remained. SQL Server, all 19 catalog registrations, and the demonstration Gold
row survived.

## Root Cause and Recovery

Kafka wrote logs and KRaft metadata into `/tmp/kraft-combined-logs`; the named
volume was mounted at `/bitnami/kafka` and empty. This storage gap had been noted
but left unresolved in the earlier recovery. Container recreation discarded
the actual logs, including connector configurations, offsets and control data.

Stopped Connect, Schema Registry and Kafka; backed up the current stopped 1.2 MiB
log directory under `.runtime/kafka-storage-backup-20261029164436/`; copied it
into the empty `mbs-poc_kafka-data` volume; corrected both the log directory and
mount to `/var/lib/kafka/data`; then recreated Kafka and restarted its readers.

Existing Iceberg snapshots retained old control offsets (1,756,664 for Customer
Lead). Reusing the lost control topic's name would skip fresh low-offset commits.
Made the control-topic name configurable, kept the existing default for intact
installations, and set this laptop's `.env` to
`mbs_iceberg_control_recovery_20261029` for the one-time recovery. Restored the
source and 15 report sinks from existing templates. No source rows were edited.

The first restored source task hit a Schema Registry write timeout. A Registry
restart, successful idempotent schema-registration check and failed-source-task
restart recovered it. Both local database snapshots completed. Customer Lead
Raw grew from 14 to 27 events, matching a replay of 13 SQL rows; Silver retained
13 current Customer Lead rows. The demonstration row still has `Latency Test
City` / `OPEN` in Gold.

## Guardrails and Checks

- Startup runners reject the old mismatched Kafka volume/log directory.
- `health:iceberg` validates the source plus all 15 report sinks, detects missing
  registrations explicitly, and rejects failed or unassigned tasks.
- Windows registration output now contains names instead of credentials in config JSON.
- Offline checks exercise the actual scripts against the observed old/new
  storage layouts, empty registrations, failed tasks and healthy tasks.
- Compose volume alignment, PowerShell syntax, Bash syntax and the offline
  checks passed.

## Container Recreation Proof

Saved connector names and source offsets, stopped readers and broker cleanly,
then force-recreated the broker using the same named volume and restarted both
readers. The broker container ID changed. All 16 names reloaded from Kafka;
both source database commit positions matched the pre-recreation values with
snapshot completion retained. A short 5-second initial cursor request timed out
during startup; the warmed worker returned both cursors successfully.

Raw remained at 27 events after restart, Silver at 13 current Customer Lead rows,
and the user's demonstration row remained unchanged in Gold. All 19 catalog
tables survived, the Customer Lead Avro schema passed a registration round trip,
and scheduled report runs succeeded with the DAG unpaused. Both dashboards
remained off.

The manually created catalog volume lacks Compose labels, so its warning is
informational. Its data and attachment were preserved. Airflow init is a one-shot
container; an exit with code 0 is normal.

See [Decision 007](../docs/decisions/007_kafka_log_storage.md) and the
[execution runbook](../docs/runbooks/02_poc_execution.md).
