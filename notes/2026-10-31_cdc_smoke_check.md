# One-command CDC regression — 2026-10-31

Step 3 of the agreed small cleanup, starting from merged PR #2 (`39c91b4`).
Reuse the existing connector preflight, keyed CDC models and deletion assertion.
No source schemas, connector settings, services or model SQL change.

The Windows runner's `test:cdc` command creates its own GUID-suffixed synthetic
lead, observe its create/update/delete in Raw, rebuild the two dependent models,
assert the current Silver/Gold values, and rebuild once more to check the deleted
row stays absent. Raw history remains append-only.

Temporarily pause the report DAG, drain an active scheduled run, and restore its
original pause state afterward. Refuse queued/concurrent test work rather than
cancelling unrelated jobs. Only the generated tag plus `CDC-SMOKE-CHECK` marker
may be updated/deleted. Clean up on ordinary failures and preserve the original
failure even if cleanup also fails. No automatic connector restart or reseeding.

Use bounded polling and bounded container dbt commands. Save per-run checkpoints,
summary JSON and command logs under ignored `.runtime/cdc-smoke/<tag>/`.
An explicit `-FailAfterInsert` diagnostic will verify cleanup after an error;
that diagnostic is expected to exit unsuccessfully.

This is a local synthetic end-to-end check, not a normal-schedule latency test,
load benchmark or proof of keyless assignment correctness. If ingestion prevents
downstream cleanup, remove the source fixture where possible and report the
remaining cleanup error rather than claiming success. Abrupt process/machine
termination cannot guarantee finally-block cleanup; retain the tag/evidence for
manual recovery.

## Recorded verification

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup.ps1 test:cdc
```

Normal tag: `CDC-FIX-SMOKE-20261031-174953-1e142e2c`. Exit 0; insert/update values
matched both Silver and Gold, deletion passed, and a second rebuild kept the row
absent. All four two-model builds passed. Original DAG state was unpaused and
was restored. Total elapsed time was 700.281 seconds, including waiting for an
existing scheduled run to drain; this is not an ingestion latency measurement.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\health\test_cdc_pipeline.ps1 -FailAfterInsert
```

Diagnostic tag: `CDC-FIX-SMOKE-20261031-180408-22c7926e`. Deliberately started with
the DAG paused to exercise the other original-state branch. Expected exit 1 with
`Intentional diagnostic failure after insert.` Source cleanup, Raw delete capture,
cleanup rebuild and the existing read-only assertion passed; the script preserved
the paused state. Elapsed time was 100.027 seconds, `fixture_removed=true`,
`dag_restored=true`, and `cleanup_errors=[]`. The verification driver then
returned the local DAG to its original unpaused state.

After both runs, no `CDC-SMOKE-CHECK` source rows remained. Non-test Customer Lead
row count stayed 16 and its selected-field checksum stayed `-1068368385`.
After diagnostic cleanup, the owned Gold row count was 0 and total Gold was 11.
The source checksum is a lightweight accidental-change check, not a cryptographic
or complete business reconciliation. No model SQL changed, so verification used
the actual lifecycle instead of repeating the unchanged full dbt test suite.

Selected JSON summaries, checkpoints, model-build results and source controls
are in [the committed evidence directory](../evidence/cdc-smoke-2026-10-31/).
The `expected-failure-*` files represent a successful cleanup test, not an
unexpected pipeline failure. Full per-run logs remain local and ignored.

PowerShell syntax and command-runner help were also checked. Final connector
verification confirmed all 16 required tasks RUNNING and the report DAG unpaused.
