# Data Engineering Portfolio Roadmap — 2026-10-31

Status: research and proposed improvements only. No pipeline implementation,
service configuration, dataset, application or deployment was changed by this
research. Official source checks were performed on 2026-10-31.

Current scope update: the extended releases below are optional future work.
The agreed immediate scope is a one-to-two-day, six-step lake cleanup: baseline,
basic CDC correctness, a small regression check, targeted quality checks, clearer
scheduled-run verification, and documentation/evidence. Pulse, incremental
processing, historical modeling and larger operational work are deferred.

## Project-Specific Roadmap

### Recommendation and intended positioning

Strengthen the existing data platform before implementing the full Pulse site.
The portfolio should demonstrate SQL/Python engineering, CDC correctness, data
modeling, recovery, quality, orchestration, measurement and reproducibility.
Pulse is a downstream consumer that makes these results accessible. A small
website is useful packaging; its frontend complexity is not a project objective.
This is engineering prioritization, not a hiring guarantee or a claim that every
data-engineering role requires this exact technology stack.

Working description: a replayable CDC lakehouse for synthetic field-service
operations, with tested analytical data products and a constrained AI query demo.
Use a neutral personal brand. Do not copy the old client application or publish
its datasets. Preserve the architecture image, existing working volumes and any
separate `data_lake` directory. All changes below remain proposals.

### Baseline and specific gaps observed

| Area | Evidence already present | Next gap to close |
| --- | --- | --- |
| End-to-end path | Local source-to-Gold tests; latest saved 2026-10-30 trace reaches Gold at 153.473 seconds | This explicitly triggered Airflow; measure the normal schedule separately |
| Transformations | Eight Silver models, one Gold model; recorded 25 passing tests | All use table rebuilds; limited key/reconciliation tests |
| CDC state | Latest-row SQL exists | Silver filters out delete events before ranking; same-timestamp order can be ambiguous |
| Business grain | Active, ICICI, archived and purge sources are consolidated | Explicit canonical business key and cross-source precedence are missing |
| StarRocks table keys | Model configurations specify `keys` | `keys` alone is a sort-key setting, not proof of a Primary Key table or unique results |
| Scheduling | Five-minute Airflow DAG, max one active run | One Bash task runs `dbt run` then `dbt test`; publication happens before quality results |
| Recovery | Kafka volume/catalog/connector/cold-start recovery notes | Planned failure tests are partly smoke tests; full backfill/replay proof remains |
| Outage harness | Stops/restarts the Connect worker | Stopping this shared worker stops both Debezium and sinks; does not demonstrate sink-only Kafka buffering |
| Observability | Health scripts and monitoring guidance | Data freshness, reconciliation and consumer lag need measured evidence; dashboard services are not implemented in current Compose |
| Reproducibility | Windows/Linux runners and useful recovery decisions | Floating image tags, old machine-specific README paths, mixed old/new milestones and `TBD` lessons |
| Public evidence | Local latency CSVs exist | `.gitignore` excludes screenshots/CSV evidence; only `screenshots/AGENTS.md` is tracked |
| Source control/CI | Current lake implementation is committed | No `.github` CI directory found in this workspace; real `dbt/profiles.yml` is tracked and needs a publishability review without assuming it contains a secret |

Sources: `dbt/models/silver/*.sql`, `dbt/models/silver/schema.yml`,
`dbt/models/gold/schema.yml`, `dbt/dbt_project.yml`,
`infra/airflow/dags/mbs_dbt_silver_gold.py`,
`scripts/latency/report_flow.ps1`, `scripts/failure/connect_pause.ps1`,
`infra/docker-compose/docker-compose.yml`, `.gitignore`, `lessons_learned.md`,
the earlier project audit in this chat and dated recovery notes. Inspection was
read-only; no delete/load/failure scenario was executed in this planning stage.

### Release 1 — trusted CDC and analytical contracts

Define source-local identities separately from the canonical business lead key.
Give current lead state, status events, assignment events and each output table a
written grain. Specify what archive/purge movement means and how duplicate
business leads are resolved across physical source tables. Establish a report
regression baseline before changing that behavior.

Retain raw deletes and source-order metadata. Resolve the identity from key or
before-image when after is null; rank all relevant events before applying the
current-state deletion policy. Preserve a stable ordering within each source;
do not impose a fictional global order across independent databases. Confirm
which metadata survives the sink before selecting the implementation.

Build a small deterministic Python workload generator and independent expected
state ledger. Python should do real data work: generate relationships, mixed
changes, event scenarios, control totals and evidence manifests. Start with tens
of carefully designed rows. Do not begin with a large random dataset that makes
the right answer unknowable.

Mandatory scenario matrix:

| Scenario | Required outcome |
| --- | --- |
| Snapshot then insert/update | Current values and expected aggregate match |
| Two changes with equal timestamps | Source order determines the winner repeatably |
| Delete | Current serving row disappears or is explicitly marked per contract |
| Delete then recreate same key | New valid state appears, old state does not revive |
| Replay a selected event range | Current-state keys and business aggregates remain identical |
| Delayed older business event | It is included in history without overwriting newer current state |
| Active-to-archive move | One canonical current lead, according to the stated business rule |
| Reference/dimension update | Dependent Gold attributes change correctly |
| Null or invalid key | Explicit rejection/quarantine outcome; no silent accepted current row |
| Additive/breaking schema change | Compatible event handled; incompatible change stops/quarantines visibly |

Separate broker/Avro contract failures, source CDC capture-schema changes and
semantic business-rule failures. Automatic Iceberg schema evolution does not
make every source DDL change safe. Keep an error table or small rejection record
with reason, source coordinates and retry/replay instructions where feasible;
some connector-level failures should stop visibly instead of being silently skipped.

Add dbt key, referential-integrity, accepted-label, date and domain-invariant
tests plus source-to-target reconciliation at the same business scope and stable
boundary. Raw event counts are not source table counts. Current-state source
totals are not directly comparable to Gold totals with different date filters,
joins or exclusions. Include hand-derived expected results; repeating the same
calculation twice does not create independent verification.

Exit proof: the scenario matrix passes, source-versus-serving comparisons have
zero unexplained differences, and a deliberately corrupted case fails a check.
Fallback: preserve the known working full-rebuild report, restrict claims to its
proven behavior, and resolve identity/order unknowns before optimization.

### Release 2 — recoverable, reproducible operation

Split orchestration into meaningful stages: readiness/input-boundary capture,
candidate transforms, validation/reconciliation, publish, and run-evidence
recording. Use dbt's dependency graph inside transformation stages rather than
creating one arbitrary Airflow task per SQL file. Track data intervals, retries,
checkpoints and run IDs explicitly. Publish only a checked candidate; keep the
last successful serving version on failure. A failed test after overwriting the
public table is not sufficient protection.

Test sink-only pause while the source continues, source pause while SQL CDC
retains changes, whole-worker restart, and consumer-facing warehouse interruption
as separate failure modes. Record queue growth, task status, catch-up duration and
post-recovery reconciliation. Use retained Raw data to rebuild into a separate
candidate schema and compare against the stable reference. Never reset the only
working consumer position merely to demonstrate replay.

Add a bounded connector-managed incremental snapshot/backfill exercise on a
synthetic table while source changes continue. Prove concurrent updates/deletes
are represented after completion. Treat the existing bulk-export ADR as an
unimplemented sketch needing a full boundary protocol, not a ready no-gap recipe.

Make clean setup reproducible: pin tested image versions/digests and dependencies,
document resource budgets/ports, keep portable example configuration, remove old
absolute paths, fill lessons with the real Kafka/catalog/memory incidents, and
document clean setup separately from restart with existing data. Review tracked
configuration before public release; do not print secret values in evidence.

Add a small CI workflow for Python logic/scenario checks, configuration validation,
dbt parsing/compatible fixture tests and document/link checks. Target-engine SQL
must also have an integration test; SQLite or mocks are not proof of StarRocks
behavior. The complete lake integration can initially run through a documented
local or explicitly triggered workflow. Do not assume a small free CI runner can
host the full memory-heavy stack.

Create a tracked, sanitized `evidence/` convention with compact summaries: dataset
seed, Git revision, image versions, expected/actual results and run outputs.
Keep bulk logs and local backups ignored. Reject duplicate/retried evidence
mislabelled as an independent success. Record generated dbt docs/lineage artifacts
or how to reproduce them; a separate metadata-platform deployment is unnecessary.

Exit proof: a clean environment reproduces the sample, an injected quality failure
does not publish, replay and pause/restart scenarios converge, and CI catches a
known regression. Fallback: local deterministic verification and a checked static
snapshot while an integration environment is unavailable.

### Release 3 — measured efficiency, history and observability

Benchmark the correct full rebuild before implementing incrementality. Try the
smallest supported change on one model. Track affected keys/partitions using a
durable ingestion/source boundary, handle overlap and deletes, and advance the
checkpoint only after successful output validation. Dimension changes must
invalidate all affected leads; an updated small lookup can affect many old rows.
Old and new date partitions both matter when a record moves date. A finite
lookback requires an explicit late-arrival limit and periodic reconciliation or
rebuild beyond that limit.

Do not promise dbt `merge` support. Validate the pinned adapter/server first;
evaluate tested primary-key/upsert or affected-partition replacement behavior,
including explicit deletion semantics. Compare the result against a full rebuild
after inserts, updates, deletes, late changes, reference-data changes and retries.
Fallback: correct full rebuild or a smaller documented batch scope until a
supported incremental strategy is proven.

Add one event-grain Gold fact from status/assignment history and small date,
agent/team and status dimensions where meaningful. Keep current-state reporting
available. Implement one limited SCD Type 2 example, such as an agent's team
assignment with valid-from/valid-to dates; show event-time attribution to the
historically correct team. Avoid turning every field into SCD2. Repeated source
events must not create duplicate history, and a current snapshot cannot
retroactively manufacture missing business events. Validate time ranges and
cross-source relationships before adding status/success metrics to Pulse.

Load tiers: deterministic small fixture, roughly 10,000 leads, roughly 100,000
leads, then a larger tier only if laptop memory/disk and elapsed time permit.
Include inserts, updates and deletes, plus skewed state/channel distributions.
One useful sustained baseline is 10 source changes/second for 30 minutes (18,000
changes), with achieved rate reported alongside the requested rate. Do not count
this as demonstrated until it runs and reconciles.

Measure p50/p95/p99 source-to-Raw and source-to-published-Gold latency, sample
count, missing/failed observations, dbt build time, rows/bytes scanned where
observable, file count/size, resource use and recovery catch-up. Measure manual
trigger and normal schedule separately, with arrivals spread across scheduling
phases. A five-minute schedule adds up to a scheduling interval of wait; a
153-second forced-run sample cannot establish a five-minute tail-latency promise.
Start with an explicit workload-specific target, for example p95 scheduled Gold
latency below ten minutes, then tighten only after measurements justify it.
All such thresholds are proposed targets, not achieved metrics.

Inspect Iceberg small files and partition pruning. Choose one measured optimization
and report before/after profiles with identical queries, cache conditions and
resource budgets. Test maintenance on a disposable table using a supported client;
do not add Spark or Flink unless a documented operation cannot otherwise be
demonstrated and the learning value justifies the resource cost. Distinguish
Kafka retention, retained Raw event rows and retained Iceberg table snapshots.

Expose actual data health: failed connector tasks, source/consumer lag, advancing
watermarks, last successful publication, quality failures, reconciliation drift,
build duration and disk pressure. Silence is not always stale data: an idle source
needs a heartbeat/control event or other explicit liveness signal. Begin with
existing scripts and structured run records, then add a compact optional
Prometheus/Grafana view if it improves diagnosis. For centralized logs use a
maintained collector; Promtail reached EOL on March 2, 2026.
[Grafana Promtail status](https://grafana.com/docs/loki/latest/send-data/promtail/).

Exit proof: incremental/full rebuild equivalence, an explained benchmark, one
correct historical query, and a dashboard/control report that detects a running
but stalled pipeline. Fallback: retain source logs/evidence and the full rebuild;
do not replace correctness with a faster but unexplained result.

### Release 4 — public data-product and AI showcase

Build the small website after Release 1 and basic Release 2 gates; extensive
frontend work should wait. An early static architecture/evidence page is fine if
it does not divert effort from the core. Complete the performance/history
evidence before claiming the project is finished. Reuse the previously researched
snapshot-based free hosting design, with account eligibility checked at deployment.
See the [Pulse code and hosting research](2026-10-30_pulse_portfolio_research.md).

Show three things: the system and its tradeoffs; an explorer/chat over an
explicitly synthetic, dated Gold snapshot; and reproducible engineering evidence.
Publish a column-allowlisted snapshot only after the same quality gates. Include
dataset version, source model revision, time coverage and publication time. Verify
hosted query results match the checked local export. The public serving database
is a copy, not a live local-StarRocks connection; a laptop shutdown must not break
the portfolio overview or fixed sample reports.

For the AI extension, preserve the constrained selection design: the model picks
allowed metrics/groupings/filters; validated code constructs parameterized queries;
the database supplies numbers; deterministic text and chart rules present them.
Unknown metrics and uncertain mappings clarify or abstain. Keep the ability to
inspect the chosen metric, date window and SQL without requiring visitors to
understand internal technology to ask a question.

Build approximately 40-60 independent evaluation cases covering paraphrases,
dates, filters, ambiguous requests, follow-ups, unavailable metrics, injection
attempts, empty results and quota failures. Split development examples from a
held-out set before tuning prompts. Record model/prompt/metric/dataset versions,
valid-selection rate, execution/result accuracy against approved query results,
abstention behavior, unsafe-selection rejection, latency and quota consumption.
Correct SQL for an incorrectly interpreted question is still an incorrect answer.

Use a single short model call where possible; keep guided reports/static examples
as labelled fallbacks. No vector store or general autonomous agent is needed for
these structured metric queries. This provides applied-AI integration evidence;
it does not demonstrate model training, model serving or production ML evaluation
on real outcomes. A predictive model/feature store is a separate optional project
direction requiring real label semantics and point-in-time data, not an MVP task.

Exit proof: a visitor can explore without an account; supported answers match the
published dataset; version/freshness is clear; unsafe/unsupported requests fail
honestly; free quota exhaustion leaves static evidence accessible. Fallback: the
same data product with guided questions and no model inference.

### Priority, effort and what should wait

Suggested work allocation is roughly 70% data engineering, 20% applied-AI/data
consumption and 10% presentation. Adjust this as effort is measured. Prefer
completion gates to dates; the four releases are an order, not a deadline promise.

| Priority | Work | Main skill demonstrated | Dependency |
| --- | --- | --- | --- |
| Essential first | CDC deletes/order/identity, deterministic workload and reconciliation | SQL, Python, data correctness | Written source and business-grain contracts |
| Essential | Replay/backfill, release gates, portable setup and small CI | Operational ownership and reproducibility | Correct transformations |
| High value | One correct incremental path and measured benchmark | Performance, state management, cost awareness | Full-rebuild correctness reference |
| High value | Event fact and one SCD2 historical example | Modeling and temporal semantics | Stable identifiers and event contracts |
| High value | Lightweight freshness/quality/lag evidence | Data observability | Known successful-run/input boundaries |
| Showcase | Small public explorer/Pulse, held-out AI evaluation | Data products and applied AI | Checked synthetic Gold and publication contract |
| Optional | Dedicated Spark batch exercise, bounded larger-load/cloud/IaC trial | Role-specific extra evidence | Concrete learning requirement and resource budget |

Do not add multiple brokers/query engines, Kubernetes, HA/DR, production IAM/RBAC,
a feature-store platform or a vector database merely to lengthen the stack.
Spark/PySpark can be a worthwhile later exercise if targeted job descriptions
explicitly call for it: implement one bounded batch transformation and compare
it with the established SQL reference. It is not required to make the present
architecture valid. Cloud-service mappings can be explained, but local MinIO
and Docker use should not be described as hands-on production AWS deployment.
Strict ₹0 does not require keeping the complete lake online continuously.

### Interview and resume evidence

Prepare a ten-minute walkthrough: business problem and grains; source change
through the layers; delete/replay correctness; failure and recovery; measured
performance; public data product and its limits. Keep a short recording as a
fallback to local Docker startup. Explain why each component exists and the
rejected simpler alternative, including why Gold is currently native StarRocks
while Raw is Iceberg. Full Gold-on-Iceberg portability is an optional decision,
not an automatic reason to rebuild the serving layer.

Retain three concise incident writeups with symptom, competing hypotheses,
evidence, root cause, fix and prevention: Kafka log-volume loss; connector/client
transaction recovery; catalog/memory/cold-start recovery. Fill
`lessons_learned.md` from those real events. These are already substantive
engineering experiences even before new functionality is added.

At completion, resume bullets should name measured volume, achieved rate,
scheduled latency, tested recovery and correctness results. Until benchmarks
are completed, leave numbers out. For AI roles add held-out question/result
accuracy and refusal/quota behavior. Do not claim production scale, complete
end-to-end exactly-once, multi-node availability or unrestricted data chat.

The immediate first slice is small: define lead grain and delete behavior;
create an independent mixed-change fixture and show the current failure; repair
that one state path and prove inserts/updates/deletes/replay reconcile. Then
expand the pattern across the remaining models before adding the website.

## Primary-Source Technical Findings

The following support the roadmap. Recommendations are distinguished from
documented behavior; none of the proposed changes is claimed as implemented.

### CDC correctness and source identity

Debezium 2.7 SQL Server documentation describes delete events with `op=d`, a
null `after`, and old-row data in `before`; a subsequent null-valued tombstone
serves Kafka compaction. Key changes produce old-key deletion and new-key creation.
Its event metadata includes `commit_lsn`, `change_lsn` and `event_serial_no`;
the serial differentiates events sharing log positions. Restart can produce
duplicate events because offsets are periodically committed.
[Debezium 2.7 SQL Server events and recovery](https://debezium.io/documentation/reference/2.7/connectors/sqlserver.html#sqlserver-events).

Implication for this codebase: ranking only `r/c/u` after-images cannot represent
the latest deleted state. Proposed Silver logic should retain delete identity,
deduplicate/order all state-changing events, then exclude or mark the latest
deleted state. Preserve source database/schema/table/primary key and log position;
validate the exact comparator on fixtures, including equal timestamps. Timestamps
alone do not prove total source order. Kafka offsets compare only within a topic
partition, and independent SQL Server databases do not share a global LSN order.
Snapshot reads also need an explicit precedence policy. These are engineering
inferences to be verified, not a drop-in SQL prescription.

The active/archive/purge consolidation additionally needs an explicit business
identity and source-precedence contract. A source-local CDC primary key and a
cross-source business lead key solve different problems. A `UNION ALL` of latest
source rows does not by itself prove one current row per business lead.

### Delivery guarantees belong to individual boundaries

Kafka Connect's source exactly-once support requires distributed-mode worker
configuration and a connector that supports it; framework capability alone is
insufficient. [Kafka Connect user guide](https://kafka.apache.org/36/kafka-connect/user-guide/).

Iceberg 1.8.1's sink documents commit coordination and exactly-once delivery using
Kafka transactional mechanisms; Kafka 2.5+ is required. Those statements cover
the sink path, not automatic source-to-report business correctness.
[Iceberg 1.8.1 Kafka Connect sink](https://iceberg.apache.org/docs/1.8.1/kafka-connect/).

Proposed portfolio claim: demonstrate stable business results after a selected
event range is replayed and after connector restarts. Capture source identity,
Kafka partition/offset, sink commits and final unique-key/aggregate comparisons.
Do not label the entire pipeline "exactly once" on the basis of one component's
feature list. Re-snapshotting or republishing equivalent source changes under new
Kafka offsets also requires a downstream business deduplication policy.

### Incremental dbt support is adapter- and version-specific

The current official StarRocks dbt guide supports incremental materialization,
including append and partition-overwrite strategies, and explicitly states that
incremental merge is unsupported. Its feature matrix has server-version
conditions. [StarRocks dbt integration](https://docs.starrocks.io/docs/integrations/dbt/#incremental),
[StarRocks 4.0 guide](https://docs.starrocks.io/docs/4.0/integrations/dbt/).

Local manifests pin `dbt-starrocks==1.11.0`; Compose uses StarRocks 4.0 floating
image tags. The requested v1.11.0 repository tag URL was unavailable during this
review, so exact installed macro behavior has not been verified. Before designing
incremental updates, inspect the installed adapter and run a small insert/update/
delete trial with the selected strategy and table model.

Proposed approach: retain full rebuild as a correctness reference, benchmark it,
then incrementally recompute affected keys or partitions using a verified
adapter-supported strategy. Primary-key upserts alone do not remove rows absent
from an incremental SELECT. Deletions, late changes, joins to changed dimensions,
retries and watermark advancement must be covered. Filtering only on
`event_time > max(event_time)` can miss ties and late arrivals. Commit progress
only after the affected result and its checks succeed; keep an explicit rebuild
fallback rather than assuming a generic `merge` configuration will work.

### Backfill and CDC cutover need a proven boundary

Debezium's initial snapshot coordinates table reads and log position; its
incremental snapshots process keyed chunks alongside streaming and use windows
to resolve collisions. Both are documented connector mechanisms rather than an
arbitrary export timestamp. [Debezium snapshots](https://debezium.io/documentation/reference/2.7/connectors/sqlserver.html#sqlserver-snapshots),
[incremental snapshots](https://debezium.io/documentation/reference/2.7/connectors/sqlserver.html#sqlserver-incremental-snapshots).

First demonstrate the supported initial snapshot and a bounded incremental
re-snapshot on synthetic tables. For a separate bulk exporter, recording a wall
clock time or max LSN alone does not establish that all exported rows represent
one consistent state, or that Debezium will resume from that boundary. The design
must specify consistent export isolation, source-position capture, supported
connector start/resume procedure, overlap handling, delete handling, schema
stability, retention coverage and recovery after an interrupted export. Prove
changes made during export reach the final state without missing rows. If this
cannot be proven, retain connector-managed snapshots; manual offset editing is
not a routine shortcut.

### Quality gates and publication are separate responsibilities

`dbt build` runs resources and tests in dependency order; upstream test failure
can skip downstream resources. It produces manifest and run-results artifacts.
[dbt build](https://docs.getdbt.com/reference/commands/build).

This is useful for the current single `dbt run` then `dbt test` task, but it does
not establish an all-or-nothing public dataset release. The model being tested
has already materialized. Proposed design: build a candidate serving dataset,
test/reconcile it, then publish that checked version and its manifest. Keep the
last known good dataset on failure. For local native StarRocks tables, atomic
swap is a documented primitive, but multi-table releases and the exact installed
version still need a tested publication contract.
[StarRocks ALTER TABLE atomic swap](https://docs.starrocks.io/docs/sql-reference/sql-statements/table_bucket_part_index/ALTER_TABLE/#atomic-swap).

Airflow's logical date describes a data interval, not task execution time; manual
runs need explicit interval handling. DAG success can also be masked by a
successful leaf task using an unconditional trigger rule. The project should
record actual inputs, source/table snapshot references, attempt, checks, output
version and publication outcome per run.
[Airflow DAG-run semantics](https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/dag-run.html).

### Iceberg maintenance should preserve the intended replay window

Iceberg 1.8.1 documents snapshot expiration, metadata/orphan cleanup and file
compaction. Expired snapshots cease being time-travel targets; files still needed
by retained snapshots are preserved. Premature orphan cleanup can delete
in-progress writes; the documented default retention interval is three days.
Small streaming files increase metadata and file-open overhead.
[Iceberg 1.8.1 maintenance](https://iceberg.apache.org/docs/1.8.1/maintenance/).

Proposed exercise: measure file count/size and query time on one disposable
synthetic table, compact with a supported maintenance client, then prove identical
row counts and aggregates. First inspect which operations the existing stack
supports; a full new Spark/Flink service is not automatically necessary. Snapshot
expiration removes old table versions, but does not remove append-only event rows
still referenced by the current Raw snapshot. Event-row retention, Kafka
retention and table-version retention are separate policies. Document their
replay/backfill consequences before enabling cleanup. Keep cleanup experiments
off the only preserved working evidence dataset.

## Unverified Implementation Questions

- Which exact Kafka key/partition/offset and SQL Server source-position fields
  survive the current sink's Raw schema, and can source database/table/key be
  recovered for deletes without ambiguity?
- Which current/archive precedence and deletion semantics define one business
  lead? What happens when a lead moves tables in separate databases?
- Which incremental strategy works with the installed adapter/server, including
  delete removal and changes to joined reference data?
- Which installed client can safely perform the desired Iceberg metadata queries
  and maintenance operations against this catalog version?
- Can candidate-table publication be made atomic for the chosen single serving
  dataset, and how is the previous successful version retained?
- What laptop-safe event volume, run frequency and load rate produce repeatable
  measurements without exhausting the existing Docker memory budget?

No answers to those questions should be inferred from tool names or a green
container status. Resolve them with small synthetic integration scenarios before
making performance or correctness claims.
