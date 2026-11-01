# Step 6: README and evidence cleanup

Started from merged PR #5 (`main` at `106d04d`) on
`codex/finalize-project-documentation`. Documentation only; no source, connector,
model, service, port or test implementation changes.

- Replaced the scaffold/client-first README with the current local synthetic
  project, setup, daily checks, endpoints, limitations and walkthrough links.
- Corrected Raw Iceberg versus native StarRocks Silver/Gold storage. Restored
  missing user/pincode models to the source/model documentation inventories.
- Organized existing results through `evidence/README.md`; original measured
  artifacts and historical test counts remain unchanged.
- Documented destructive sample bootstrap as first-time setup, not daily recovery.
  Chose the already verified container dbt runtime as the primary Windows path;
  the local Python alternative needs `.venv` creation before its dbt installer.
- Marked older Linux/client/EC2/monitoring material as reference context. Linux
  lacks the Windows Airflow/smoke commands; no free public hosting or Power BI UI
  refresh is claimed. Corrected reusable links instead of moving evidence files.
- Added a short project/interview walkthrough and filled the lessons/limitations
  from observed results rather than adding a production-hardening roadmap.

## Verification

- Checked 57 Markdown files: 140 local links and 16 Markdown section anchors pass.
- All 18 README runner command names exist; documented host endpoints match Compose.
- Runbook inventory matches the 15 Raw source definitions and nine dbt SQL models.
- Command-runner help executes; whitespace checks pass.
- Only Markdown files changed. The original architecture image and all recorded
  measurement directories remain unchanged; no existing data_lake content changed.
- Clarified queued-run handling: let queued work finish while unpaused before
  pausing/draining active work; pausing alone cannot drain a queue.

This step does not rerun data mutations or claim a fresh empty-volume
installation. Runtime evidence remains the actual results from Steps 1-5.
The local checking script is ignored under .runtime/docs-step6/.
