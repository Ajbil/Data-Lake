# Current project limitations and risks

This is a single-node local synthetic-data POC. The table describes actual scope
and remaining gaps after Steps 1-5; it is not a production-hardening backlog.
The [evidence index](evidence/README.md) links the observations behind these limits.

| Area | Current limitation / impact | Practical handling |
| --- | --- | --- |
| Active assignment log | No stable source row key; updates/deletes/replay are outside keyed CDC guarantees | Keep the exception explicit; a source key and new validation would be needed to extend the guarantee |
| Source ordering | Macro assumes canonical fixed-width LSNs and immutable event coordinates within one physical source | Database restore/LSN reset or conflicting same-position payloads require a separate recovery policy |
| Lead identity | Same reference/ID can occur across active/archive sources | Validate `(source_table, customer_id)` and preserve eligible Gold multiplicity; do not claim canonical business deduplication |
| Publication | Full table rebuilds happen before tests; readers can see transient tables and a failed test does not roll back Gold | Avoid overlapping builders; inspect complete run success before using a demo snapshot |
| Report dates | Date window starts at month start two months earlier; static demo rows eventually age out | Treat committed counts as dated observations; use newly generated synthetic leads for live checks |
| Verification | 32 bounded tests are not full source-to-target reconciliation or proof of exactly-once processing | Present what the fixtures/lifecycle checks prove and their source-key boundary |
| Ingestion failures | Baseline found failed sink tasks; targeted restarts recovered them but did not establish a permanent root-cause fix | Inspect actual task states/logs and storage before recovery; a healthy wrapper or restart is insufficient proof |
| Retention/storage | CDC retention, disk capacity and single-node outages can interrupt capture or commits | Preserve offsets, Kafka logs, catalog registrations and warehouse; no destructive reset as routine recovery |
| Reproducibility | Some images use floating tags; the six-step cleanup ran on an existing installation | Use recorded image/config evidence; no fresh empty-volume or cross-platform test is claimed |
| Performance | Five-minute scheduling and individual observed timings do not prove throughput, tail latency or BI freshness | Keep scheduling proof separate from latency observations and manual rebuilds |
| BI / public access | SQL serving is verified; final Power BI UI refresh and public Pulse/AI website are outside cleanup proof | Demonstrate Gold with SQL; treat UI/hosting as separate future work |
| Operations / cost | CLI checks and task logs are implemented; monitoring-stack/EC2 documents are historical proposals | No new monitoring stack or cloud resources are required for the local project; EC2 is not a zero-cost hosting solution |
| Sample setup | Report bootstrap drops/recreates local report tables and CDC instances | Use once for a new disposable sample; never use it as daily recovery |

See the [Airflow recovery guide](docs/runbooks/03_airflow_failures.md) for failure
inspection. Historical milestones and the extended portfolio roadmap are optional
context; the agreed small cleanup does not require completing those larger plans.
