# Working Baseline — 2026-10-31

Scope: step 1 of the agreed six-step, one-to-two-day lake cleanup. Record the
existing behavior before changing CDC logic, models, tests or configuration.
Pulse and the extended portfolio roadmap are deferred. No implementation files
are changed by this baseline PR.

## Git workflow

Create the branch before committing pending work. The two previously untracked
files were research notes, not pipeline changes. They are retained in their own
commit and explicitly mark the larger roadmap/application work as deferred.

1. Inspect `git status --short` and `git branch --show-current`.
2. Fetch `origin/main` and confirm local `main` matches it.
3. Create `codex/record-working-baseline` from that unchanged main commit.
4. Commit the two research notes separately from baseline evidence.
5. Record this baseline, review the evidence, and make a second commit.
6. Push the branch and open a PR targeting `main`; review/merge separately.

Starting implementation revision: `54fb17e9ccb1ee5023e5cda4d5f9a19bd4114e59`.
Research-note commit: `0733b9ac836bbd0ef0c322c534aadeccccc8b1e8`.
Only documentation differs between those revisions; the tested implementation
is unchanged. Existing running containers use this workspace's bind mounts and
preserved local data; this is not a clean-machine installation test.

## Reproduce the baseline checks

Run PowerShell from the repository root. Keep `.env` local. These commands use
the existing setup scripts; no bootstrap/reseed or volume recreation is needed
when the stack is already running.

1. Inspect services:

   ```powershell
   docker compose --env-file .env -f infra/docker-compose/docker-compose.yml ps
   ```

   FE/BE should be healthy, with the source, broker, registry, Connect, catalog,
   MinIO and scheduler running. Successful one-shot init containers can be exited.
   Kafka UI and the Airflow webserver are optional and were left off.

2. Check every required connector task, then the serving engine and Raw queries:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup.ps1 health:iceberg
   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup.ps1 health:starrocks
   ```

   A RUNNING connector wrapper does not imply its tasks are RUNNING. If a check
   fails, retain its output before any recovery and do not insert a latency row.

3. Record counts before inserting a sample. The source query is
   `sql/verification/report_sample_counts.sql`. It can be run against the existing
   local SQL Server without displaying its password:

   ```powershell
   Get-Content -Raw .\sql\verification\report_sample_counts.sql |
     docker exec -i mbs-sqlserver bash -lc 'export SQLCMDPASSWORD="$SA_PASSWORD"; if [ -x /opt/mssql-tools18/bin/sqlcmd ]; then /opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -l 10 -t 30 -b; else /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -l 10 -t 30 -b; fi'
   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup.ps1 health:dbt
   ```

   The committed count evidence additionally covers all 15 report Raw tables,
   all 8 Silver models and Gold. Source rows, CDC event rows and reporting rows
   are different populations; their counts are not expected to match directly.

4. Once connector preflight is green, run one dedicated, uniquely tagged example:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\latency\report_flow.ps1 -Tag BASELINE-your-unique-tag -TimeoutSeconds 600
   ```

   Use a NEW tag for a deliberate new run. The script inserts one synthetic lead,
   one assignment and one campaign record, traces Kafka and Raw, and explicitly
   triggers the Airflow DAG to refresh Gold. Do not reuse an old tag, reseed the
   database, or delete source rows as part of baseline collection. Existing
   demonstration rows should remain intact.

5. Verify that the triggered Airflow run succeeds, not just that Gold is visible.
   Inspect its task log for successful model/test totals. Gold can become visible
   before subsequent dbt tests finish. The run ID is `latency_` followed by the
   tag with hyphens replaced by underscores.
6. Repeat the connector health check and counts. Save expected count changes,
   representative Gold fields, test totals, timing and any unresolved limitations.

See the [execution runbook](../docs/runbooks/02_poc_execution.md) for stack startup
and the [earlier recovery note](2026-10-29_report_latency_recovery.md) for history.
This baseline does not change either procedure.

## Observed initial state

Baseline collection began at **12:48 IST on 2026-10-31**.

- Core services had been up for approximately 15 hours. FE and BE were alive and
  healthy. Optional dashboards remained stopped.
- SQL Server CDC was enabled on both captured databases.
- Schema Registry returned 31 subjects.
- StarRocks health verification passed and listed all 19 Raw registrations.
- **Initial connector verification failed:** the source task was RUNNING, but
  all 15 report sink tasks were FAILED while their connector wrappers said RUNNING.
- Traces included coordinator termination and Kafka transaction/control-topic
  timeouts. This observation does not identify the underlying cause.
- Recent scheduled Airflow runs were succeeding, demonstrating that successful
  transforms can coexist with failed live ingestion.

Initial key counts:

| Population | Count |
| --- | ---: |
| Source Customer Lead | 15 |
| Customer Lead Raw CDC events | 31 |
| Consolidated Silver customer leads | 18 |
| Gold report rows / distinct order numbers | 10 / 10 |
| Gold null order numbers | 0 |

All 10 initial Gold rows were Fresh, Serviceable and High-priority. These are
observations of this local sample, not general business expectations.

## Operational recovery during collection

Saved the initial task states and counts before recovery. Issued one restart
request for each FAILED sink task using the existing Connect task-restart API;
all 15 requests returned HTTP 204. Source task, connector definitions, consumer
offsets, Kafka storage, catalog and existing source records were not reset.

The original `health:iceberg` check then passed: source plus all 15 sink tasks
were RUNNING. This is a recovered working state, not proof of a permanent fix or
overnight stability. Root-cause diagnosis is outside this baseline-only change.

## Fresh end-to-end example

Tag: `BASELINE-20261031-125420`.

The existing latency command completed with exit code 0. Checkpoints below are
observations measured from command start, not exact component processing times.

| Checkpoint | Elapsed seconds |
| --- | ---: |
| Source insert command returned | 6.157 |
| Kafka event observed | 57.223 |
| Raw Iceberg row observed through StarRocks | 63.185 |
| Explicit Airflow trigger command returned | 229.188 |
| Gold row observed | 233.259 |

The command finished at 235.768 seconds. The 166-second interval between the Raw
observation and trigger-return includes Airflow CLI overhead. Gold was already
visible while the explicitly requested run was queued. A regular scheduled run
was active, so the manual run must not be credited with publishing the observed
row. The probe did not continuously poll Gold during that CLI interval; 233.259
seconds is an observation upper bound, not its precise first-availability time.

The explicit verification run `latency_BASELINE_20261031_125420` subsequently
completed successfully from **12:59:31 to 13:02:52 IST**. Its task log records:

```text
Models: PASS=9 WARN=0 ERROR=0 SKIP=0 TOTAL=9
Tests:  PASS=25 WARN=0 ERROR=0 SKIP=0 TOTAL=25
Airflow task/run: success
```

Final Gold fields for the tagged example:

| Field | Value |
| --- | --- |
| record_type | Fresh |
| champaines | High-priority |
| serviceable_pincode | Serviceable |
| agent_id | AG001 |
| source_system | LATENCY-CHECK |

Expected count changes were observed: source lead 15 to 16, assignment 15 to 16,
campaign 14 to 15; each corresponding Raw table gained one event; corresponding
Silver lead/assignment/campaign tables each gained one row; Gold rose from 10 to
11 rows with 11 distinct order numbers. The other sampled table counts did not
change. Subsequent cleanup comparisons should start from the **after** counts.

The count-only `health:dbt` command briefly saw `silver_mbs_user = 0` while a model
was being rebuilt, despite exiting successfully. A post-run query returned 10.
This is captured as observed transient read behavior, not a new fix or a claim
that the current health script rejects empty tables. Counts are separate queries
against a running system, not a transactionally consistent multi-table snapshot.

Final connector verification passed again with all 16 required task states
RUNNING. Source records added for this check were retained; existing sample and
visual-demo records were not edited or deleted.

## Committed evidence

The [baseline evidence directory](../evidence/baseline-2026-10-31/) contains only
selected aggregate counts, task states, image IDs, task-restart timestamps,
checkpoint timing and verification summaries. No `.env`, connector config,
customer contact fields, database dump or unrestricted container log is included.

- [Counts before](../evidence/baseline-2026-10-31/counts-before.csv),
  [counts after](../evidence/baseline-2026-10-31/counts-after.csv) and
  [all 39 count comparisons](../evidence/baseline-2026-10-31/count-deltas.csv).
- [Initial task states](../evidence/baseline-2026-10-31/connector-status-before.csv)
  and [final task states](../evidence/baseline-2026-10-31/connector-status-after.csv).
- [Timing checkpoints](../evidence/baseline-2026-10-31/latency.csv),
  [Airflow outcome](../evidence/baseline-2026-10-31/airflow-verification.txt),
  [model/test summary](../evidence/baseline-2026-10-31/airflow-task-summary.txt) and
  [final Gold example](../evidence/baseline-2026-10-31/gold-example.txt).

Full local working captures remain ignored under
`.runtime/baseline-2026-10-31/`; the original timing CSV also remains under
`screenshots/`. The recovery and single example are runtime operations; merging
this documentation PR does not repeat them.

## Limits and next step

This records observed health and basic insert-to-Gold behavior. It does not prove
delete handling, event ordering, source-to-target reconciliation, replay safety,
clean installation, Power BI refresh or normal-schedule latency. The explicitly
triggered latency example must not be presented as a scheduling SLO.

Next cleanup step: investigate/fix basic CDC correctness against controlled
synthetic cases. The initial sink failure remains a separately recorded
operational follow-up; a restart is not a root-cause correction.
