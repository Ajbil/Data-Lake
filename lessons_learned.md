# Lessons learned

These lessons come from the local implementation and the dated checks in the
[evidence index](evidence/README.md).

## CDC correctness comes before a dashboard

Filtering deletes before ranking left a deleted lead visible in Silver/Gold.
The corrected macro ranks all operations by source position, then removes a
latest delete. Reversed clocks, equal timestamps, replay and delete/recreate
fixtures demonstrate why arrival time alone is insufficient. This guarantee
still needs a stable physical source key.

## Define grain before adding a uniqueness test

Active/archive/purge tables form a union, not a canonical business-lead table.
The physical key is `(source_table, customer_id)`. Gold count comparisons must
use eligible source/reference groups and preserve multiplicity; a global unique
order-number check could reject valid data. Raw CDC events also cannot be
reconciled one-for-one with current entities or a filtered report.

## A successful wrapper is not a healthy pipeline

At baseline, source/connector wrappers could appear running while sink tasks had
failed. Check required task states and observe a real change in Raw. Targeted
restarts recovered the measured baseline but did not prove a permanent fix.
[Baseline note](notes/2026-10-31_working_baseline.md).

## Test failure and success paths

The CDC smoke check verifies insert, update, delete and another rebuild, then
cleans its own source row. Its intentional failure path demonstrates cleanup
without editing existing samples. Isolated bad-data fixtures prove the quality
checks actually reject violations, while null-agent/cross-source cases still pass.

## Scheduling, freshness and publication are different

A scheduler-created run is stronger scheduling evidence than a forced manual
build. Neither proves a latency SLA. The current `dbt run` then `dbt test` task
reports failures clearly but rebuilds tables before testing; quality failure does
not provide rollback. Do not overlap direct builds with scheduled work.

## Preserve state and make the next engineer's path explicit

Kafka logs, the catalog database and MinIO files all need persistence. Migration
and cold-start notes explain observed failures; deleting volumes would discard
that state. Use the current README, keep optional dashboards off unless useful,
and distinguish recorded evidence from proposed infrastructure. The source
sample bootstrap is destructive setup, not a restart command.
