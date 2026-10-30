# Decision 006: Preserve and Serialize the Local SQLite Catalog

## Status

Verified for local recovery, 2026-10-29. All 19 registrations and the current
snapshot survived a catalog restart. Fresh full tests passed in 293.279 and
143.056 seconds, with the normal scheduler restored and dashboards off.

## Evidence and Decision

The catalog again returned `SQLITE_BUSY` while the report sink attempted commits.
Its SQLite database was in the container writable layer, without a volume.
Before replacing the container, stop ingestion and the catalog, copy the entire
database, verify SQLite integrity and table registrations, and restore it into a
named Docker volume. Keep the existing table metadata locations and MinIO files.

Use one JDBC connection (`clients=1`) for this single-node catalog and a 30-second
SQLite busy timeout with WAL journaling. Apache Iceberg's JDBC pool defaults to
two connections; serializing local catalog operations removes competing SQLite
writers within this process. This remains a small local POC, with PostgreSQL as
the next choice if catalog concurrency grows.

Kafka Connect feeds this catalog; StarRocks reads its table locations. Verify
all existing registrations survive, concurrent catalog commits succeed, and
the original waiting sample plus fresh SQL-to-Gold tests pass. Preserve the
pre-migration SQLite copy in ignored `.runtime/` for rollback. Never initialize
an empty replacement over an existing catalog or reset Kafka consumer offsets.

## Probe Memory

The 7.6 GiB Docker VM exhausted all 2 GiB of swap during recovery. Kafka CLI
probes inherit the broker's heap settings. Terminating only those temporary
probes freed over 2 GiB. Set `KAFKA_HEAP_OPTS='-Xms32m -Xmx128m'` on the latency
console consumer. Apply the same override to manual Kafka CLI diagnostics.
Keep optional dashboards off. Check actual memory after restoring the full
pipeline; a passing test while its scheduler is stopped is insufficient.

The StarRocks FE was also configured with `-Xmx8192m`, exceeding the entire VM's
RAM, and had reached 2.2 GiB RSS for this tiny sample. Limit its Java heap to
1 GiB in the local Compose startup command, preserving its metadata volumes.
Give Connect an explicit 256 MiB initial / 1 GiB maximum heap. These are local
sample-data settings; size again for a larger workload rather than assuming
they satisfy production capacity.
