# Manual Walkthrough Preflight — 2026-10-29

## Tested Scope

Local Windows laptop, sample SQL Server databases, existing persistent Docker
volumes. No client systems or production services were involved. The user's
original demonstration row `CDC-LATENCY-20261029141350` remains `Latency Test City`
/ `OPEN` in Gold for the manual exercise.

## Fresh Insert

Dedicated tag: `CDC-PREFLIGHT-20261029180106`.

| Checkpoint | Elapsed seconds |
| --- | ---: |
| SQL Server insert | 5.129 |
| Kafka CDC event | 44.550 |
| Iceberg Raw query through StarRocks | 46.618 |
| Airflow run requested | 80.910 |
| Gold row visible | 133.000 |

The complete command finished in about 135 seconds. Evidence:
[`CDC-PREFLIGHT-20261029180106-report-latency.csv`](../screenshots/CDC-PREFLIGHT-20261029180106-report-latency.csv).

## Manual Update and Stage Separation

Paused the report DAG and waited for active runs to finish. Updated only the
dedicated tag to `PREFLIGHT-VISUAL-CITY` / `PREFLIGHT-APPROVED`, including the
source update timestamp. The SQL CDC function returned operation 3 (old values)
and operation 4 (new values). Raw contained the new `u` event while Gold still
contained the old values with the DAG paused.

Kafka UI returned HTTP 200, reported the broker online, and its message API
decoded the update through Schema Registry. MinIO Console returned HTTP 200;
an authenticated S3 list found 99 files under the Customer Lead Raw table,
including Parquet data, metadata JSON and Avro manifests.

Logged into the Airflow web application, read the DAG API, unpaused the DAG and
requested `manual_visual_CDC_PREFLIGHT_20261029180106` through its authenticated
API. The run succeeded: 9 models passed and 25 tests passed, with zero warnings
or errors. Both Silver and Gold then returned the new city/status; Silver's
operation was `u`. The web API checks and decoded Kafka event evidence are under
ignored `.runtime/client-preflight/`.

## Installed Windows Clients

- DBeaver is already installed at
  `C:\Users\caw-d\AppData\Local\DBeaver\dbeaver.exe`.
- Its installed Microsoft SQL Server JDBC 13.4 and MySQL JDBC 8.2 drivers both
  connected successfully, queried the original demonstration row and returned
  table metadata (18 source columns and 48 Gold columns).
- Prepared two additional DBeaver profiles: **MBS - SQL Source**
  (`localhost:11433`, `EKYC_ICICI`) and **MBS - StarRocks**
  (`localhost:9030`, `analytics`). Existing profiles and encrypted credentials
  were preserved; the public connection file was backed up before the addition.
  The new profiles contain no saved passwords. For SQL Server enter `sa` with
  this repository's `.env` `MSSQL_SA_PASSWORD`; for StarRocks use `root` and a
  blank password. SQL Server uses encryption with its local certificate trusted.
- Power BI Desktop 2.153.1206 and Oracle MySQL Connector/NET 9.4 are installed.
  The Windows PowerShell 5.1 registered `MySql.Data.MySqlClient` provider connected
  to `localhost:9030`, read all seven walkthrough fields from Gold, and verified
  the updated city/status. This is a real connection using the installed provider,
  not a completed Power BI Desktop report refresh.

## Limits of This Verification

The desktop automation runtime timed out even on initialization. Automatic
approval review rejected the attempted headless Chrome rendering check with
`blocked by policy`; no more specific reason was returned. Web HTTP/API checks,
JDBC connections and the .NET query passed, but DBeaver's visible connection
dialog and Power BI's preview, report save/reopen and visual refresh have not
been exercised. No desktop screenshot or PBIX report is claimed.

The Kafka container recreation test and persistent offset/configuration proof
are recorded in [the connector recovery note](2026-10-29_connector_persistence_recovery.md).
These checks establish the current local state; long laptop sleep and overnight
stability remain outside the short preflight.

## Final Startup Checks

Reran the user's exact Windows PowerShell `setup.ps1 start`, `health:iceberg`
and `health:starrocks` commands after the walkthrough test. All succeeded.
Source plus all 15 report sink tasks were RUNNING; both StarRocks FE and BE
were alive; the external catalog still listed all 19 Raw registrations.
Customer Lead Raw had 29 events after the dedicated insert/update. The offline
restart checks also passed for unsafe storage, missing registrations, failed
tasks and healthy tasks. The catalog volume's missing Compose-label warning
remains informational; its attached data was retained. Airflow init exited
successfully after its migration/user check.

Both optional dashboards were then stopped. The report scheduler remains
running and its DAG remains unpaused.

Finally ran the user's exact
`powershell -ExecutionPolicy Bypass -File .\scripts\setup.ps1 health:airflow`
with both dashboards off. Its scheduler-managed run
`health_d6fb3fcf9d5b4f45ad4467b7e24947ed` finished successfully, all 25 tests
passed again, and the command returned exit code 0 with its verification-complete
message. The DAG was still unpaused afterward. The task itself took about
three minutes; the command also spends time loading Airflow's command-line
environment and checking the run. A running-state message during that interval
is expected.

See the [Power BI walkthrough](../docs/runbooks/03_powerbi_starrocks.md) and
[execution runbook](../docs/runbooks/02_poc_execution.md).
