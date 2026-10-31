# Basic CDC correctness — 2026-10-31

Scope approved in chat: step 2 of the small lake cleanup, after merged baseline
PR #1. Branch starts at `689b447`. Retain full dbt table rebuilds and the existing
source/sink configuration. No new services or source capture-schema changes.

## Intended behavior

Each keyed physical source row has at most one current Silver row. Rank its
snapshot/create/update/delete envelopes together using SQL Server source log
coordinates before filtering a latest delete. A null delete after-image obtains
its key from the before-image. Preserve different status/log event IDs as
separate history rows; do not collapse all events for a lead into one record.
Initial snapshots at a source boundary supersede older captured versions.

Raw schema inspection confirmed `source.commit_lsn`, `source.change_lsn` and
`source.event_serial_no` are available. Compare canonical fixed-width SQL Server
LSNs within each source, with timestamps only as fallback/tie-breakers. Repeated
copies of the same immutable event should not change current results.

The active `ServiceRequestAssignLog` has no primary key or stable row ID in either
the source DDL or Raw payload. Keep its existing history interpretation and
explicitly exclude it from the keyed current-state guarantee. Do not invent a
unique key from mutable order/status/agent values. The two archived assignment
tables do have `Id` keys and can use the keyed rule.

## Verification and fallback

Reproduce the stale-delete defect before editing models, using a new tagged
synthetic lead. Retain a small target-engine fixture test of delete/recreate,
source ordering, snapshots and replay; then verify real source changes through
Kafka/Raw, the actual Silver model and Gold. Run the existing model/test suite.
Scheduled rebuilding is temporarily paused during manual checks and must be
returned to its original unpaused state. Existing demo rows are not test inputs.

If a source cannot provide a stable key or source position, record that limit
rather than claiming full CDC correctness. Cross-source business-lead identity,
incremental transforms and overnight connector stability are outside this fix.

## Reproduction and correction

Dedicated tag: `CDC-FIX-20261031-131923`, physical CustomerId `20012`.

1. With the original models, inserted one synthetic lead and verified it in Gold.
2. Deleted only that tag with `SourceSystem = 'CDC-CORRECTNESS'`; source count
   became zero. Waited for its actual Raw `d` event before rebuilding.
3. The unchanged rebuilt Silver and Gold each still returned one row. The
   persisted read-only assertion failed, so missing ingestion was ruled out.
4. A target-engine fixture using the old ranking rule returned six mismatches.
5. Added one shared macro and routed all 14 keyed source reads through it. Removed
   the old per-model timestamp ranking. No connector configuration or Raw table
   was changed. All nine models and 26 data tests passed in `dbt build`.
6. The same live assertion then passed: Raw delete count one, Silver zero, Gold
   zero. Raw history was retained.
7. Recreated the same synthetic primary key and updated its city in one SQL Server
   transaction. After the Raw update arrived, both rebuilt Silver and Gold showed
   exactly one row with `CDC Updated City`. The earlier delete did not suppress
   the new incarnation. IDENTITY_INSERT was used only for this removed test ID;
   source schemas and other rows were not altered.
8. Deleted the recreated fixture at the source. Waited for the second distinct
   delete source position, rebuilt and rechecked before restoring scheduling.

Completion: the full build passed **9 models + 26 data tests**. After the final
fixture removal, the targeted build passed **2 models + 11 tests**, including
the strengthened fixture comparison. The live deletion assertion returned Raw
delete count 2, Silver 0 and Gold 0. Gold returned to its baseline 11 rows.
The DAG's original unpaused state was restored. The live recreate/update events
shared source timestamp `1793434311860` and a commit LSN; change LSN and event
serial distinguished their order. Their selected coordinates are retained as
evidence without unrelated source payloads.

The rule assumes one physical source per Raw relation. SQL Server LSN strings
are canonical fixed-width hexadecimal values, normalized to lowercase. A snapshot
read at an equal commit boundary represents the state at that boundary; it takes
precedence over older captured changes at the boundary. Missing source positions
fall back to timestamps and do not offer the same source-order guarantee.

The [Debezium 2.7 event contract](https://debezium.io/documentation/reference/2.7/connectors/sqlserver.html#sqlserver-events)
documents delete before-images and log-position metadata; availability in this
project was verified separately through StarRocks DESCRIBE and actual Raw events.

## Runnable checks

Run the self-contained fixture using the existing containerized dbt runtime:

```powershell
docker exec -w /opt/airflow/dbt -e STARROCKS_DBT_HOST=starrocks-fe -e DBT_PROFILES_DIR=/opt/airflow/dbt mbs-airflow-scheduler /home/airflow/.local/bin/dbt test --select cdc_current_rows
```

It covers deletion with a null after-image, log position versus reversed clocks,
equal timestamps resolved by change/serial positions, initial snapshots, duplicate
event replay, delete/recreate, missing-key exclusion and a timestamp fallback.
It also checks that an identity does not produce multiple current rows.

The original live failure and successful rerun use exactly this read-only command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\health\test_cdc_deleted_lead.ps1 -Tag CDC-FIX-20261031-131923
```

This fixture exists in the retained local Raw history. Another installation must
prepare its own fixture. In a SQL client connected to the local synthetic database,
choose a new `CDC-FIX-...` tag and insert only a dedicated row, for example:

```sql
USE EKYC_ICICI;
DECLARE @tag varchar(100) = 'CDC-FIX-your-unique-tag';
IF EXISTS (SELECT 1 FROM dbo.Customer_Lead WHERE RefNumber = @tag)
    THROW 50001, 'Choose a new fixture tag', 1;
INSERT INTO dbo.Customer_Lead
    (ORDER_NUMBER, DESTINATION_CITY, PINCODE, STATE, Bank_Status,
     DTCreatedDate, DTUpdateDate, SR_Status, ChannelCode, RefNumber,
     SourceSystem, BankId, ServiceTypeID, Sub_Status)
VALUES
    (@tag, 'CDC Initial City', '400001', 'Maharashtra', 'OPEN',
     SYSUTCDATETIME(), SYSUTCDATETIME(), 1, 'DSB', @tag,
     'CDC-CORRECTNESS', 3, 1, 0);
```

Wait for the create in Raw, rebuild the two report models as described in the
[execution runbook](../docs/runbooks/02_poc_execution.md#basic-keyed-cdc-correctness-check),
and verify its presence. Update only the tag/marker-scoped row and check the new
value after another captured change and rebuild. Finally delete only that tagged
synthetic row, wait for its Raw delete, rebuild and run the read-only assertion
with that tag. Never bootstrap/reseed the working source to run this test.

## Evidence and limits

Selected outputs are retained under
[`evidence/cdc-correctness-2026-10-31`](../evidence/cdc-correctness-2026-10-31/):
the pre-fix stale-row result, six fixture failures, successful full build/test
summary, passing live deletion check, and recreated/updated values. Full local
logs stay ignored under `.runtime/cdc-correctness-2026-10-31/`.

Keyed archived assignment rows now collapse replayed CDC versions by `Id`.
The active keyless assignment branch still retains its old history behavior,
including its known update/delete and replay limitations. Resolving that requires
an agreed stable source key and capture-schema coordination; it is not hidden
behind a synthetic key. Cross-source lead deduplication is also deferred.

This fix does not establish exactly-once delivery, bulk cutover, point-in-time
history, incremental processing or overnight stability. Existing baseline/demo
rows are not edited or deleted. Final completion checks include fixture removal,
restoration of the originally unpaused DAG and connector health.
