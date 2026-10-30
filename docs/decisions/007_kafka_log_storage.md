# Decision 007: Persist Kafka's Actual Log Directory

## Status

Verified 2026-10-29. After an actual second broker-container recreation and
reader restarts, all 16 source/report connector registrations and both SQL
database source positions survived. The Kafka container ID changed while the
named data volume remained attached. The original demonstration row was retained.

## Failure and Evidence

After broker container recreation at 10:55 UTC, Connect returned an empty
connector list. It finished startup with config offset -1 and no assignments.
Only empty/new internal Kafka topics existed; the source CDC topics were absent.
The Iceberg plugin was installed correctly, but connector status returned 404.

Compose set `KAFKA_LOG_DIRS=/tmp/kraft-combined-logs` while mounting the named
`kafka-data` volume at `/bitnami/kafka`. The live log directory contained 1.2 MiB;
the named volume was empty. Broker logs and KRaft metadata therefore lived in
the replaceable container layer. An engine/container RUNNING status did not
establish that connector registrations or offsets survived.

## Decision

Configure `KAFKA_LOG_DIRS=/var/lib/kafka/data` and mount `kafka-data` at that exact
path. Stop dependent writers and the broker, back up its current stopped log
directory, and copy that complete directory (including KRaft metadata) into the
empty named volume before replacing the broker. Preserve SQL Server, MinIO,
the persistent catalog and StarRocks data. Never overwrite a populated volume.

Kafka feeds Schema Registry and Connect, stores Connect configuration/offsets,
and buffers CDC for Iceberg. Restore the missing source and 15 report sinks from
their existing templates without printing credentials. Source recovery uses an
initial snapshot of the local sample databases because the former Kafka source
offset/history topics no longer exist. Raw replay/history implications must be
checked against existing Iceberg commit metadata; Silver selects latest rows by
source primary key. This procedure is scoped to the local sample, not a client
production cutover.

The retained Iceberg snapshots store control-topic offsets under a key containing
the control-topic name and connector group. Customer Lead's old control offset
was 1,756,664. Reusing that topic name after its loss would cause new low-offset
commit events to be skipped. Set a fresh control-topic name through the local
`ICEBERG_CONTROL_TOPIC` setting for this one-time recovery. Keep the old default
for existing installations whose Kafka history is intact. Preserve that chosen
name on subsequent normal restarts. Replayed initial snapshots append Raw events;
verify Silver still chooses one current row per source primary key.

## Proof and Fallback

Verify source and all required sink tasks run, then recreate the broker again
and confirm connector registrations and source offsets survive. Check the user's
existing demonstration row through Gold without modifying it. Improve the health
check to distinguish an installed plugin from missing registrations or failed
tasks. Retain the stopped-log backup in ignored `.runtime/` for rollback.

The catalog-volume warning is separate: that already populated volume was
created manually during the preserved migration and lacks Compose labels.
Keep its contents and current attachment; never replace it just to remove a warning.

## Recorded Verification

The local resnapshot replayed 13 Customer Lead rows into Raw (14 old events
became 27). Silver retained 13 current Customer Lead rows. Subsequent broker
recreation did not trigger another snapshot; the source positions remained
`00000068:00004050:0003` and `00000069:00000608:0003`, both marked snapshot
completed. Customer Lead's existing Avro schema registered idempotently after
the restart. The demonstration row remains `Latency Test City` / `OPEN` in Gold,
the catalog retains 19 tables, and scheduled report runs succeeded.

The initial restoration hit a Schema Registry write timeout. Restarting Registry,
verifying schema registration and restarting the failed source task recovered it.
The health check now includes that source prerequisite. Offline old-layout,
missing-registration, failed-task and healthy-task regression checks passed.
