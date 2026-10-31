param(
    [ValidateRange(30, 900)][int]$TimeoutSeconds = 300,
    [ValidateRange(1, 30)][int]$PollSeconds = 5,
    [ValidateRange(60, 900)][int]$BuildTimeoutSeconds = 300,
    [switch]$FailAfterInsert
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$tag = 'CDC-FIX-SMOKE-' + [datetimeoffset]::UtcNow.ToOffset([timespan]::FromHours(5.5)).ToString('yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N').Substring(0, 8)
$evidenceDir = Join-Path $repoRoot ".runtime/cdc-smoke/$tag"
New-Item -ItemType Directory -Force -Path $evidenceDir | Out-Null
$timer = [Diagnostics.Stopwatch]::StartNew()
$checkpoints = New-Object 'System.Collections.Generic.List[object]'
$summary = [ordered]@{
    tag = $tag; status = 'running'; elapsed_seconds = 0
    diagnostic_failure = [bool]$FailAfterInsert; dag_was_paused = $null
    dag_restored = $null; fixture_removed = $true; failure = $null; cleanup_errors = @()
}
$fixtureMayExist = $false
$wasPaused = $null
$lock = $null
$completed = $false
$cleanupErrors = @()

function Save-Evidence {
    $summary.elapsed_seconds = [math]::Round($timer.Elapsed.TotalSeconds, 3)
    $summary | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 -LiteralPath (Join-Path $evidenceDir 'summary.json')
    $checkpoints | Export-Csv -Encoding UTF8 -NoTypeInformation -LiteralPath (Join-Path $evidenceDir 'checkpoints.csv')
}

function Add-Checkpoint([string]$Stage, [string]$Status = 'passed', [string]$Detail = '') {
    $checkpoints.Add([pscustomobject]@{
        stage = $Stage; status = $Status; elapsed_seconds = [math]::Round($timer.Elapsed.TotalSeconds, 3)
        observed_at_ist = [datetimeoffset]::UtcNow.ToOffset([timespan]::FromHours(5.5)).ToString('o'); detail = $Detail
    })
    Save-Evidence
    Write-Host "[$Status] $Stage $Detail"
}

function Invoke-SourceSql([string]$Sql) {
    $Sql | docker exec -i mbs-sqlserver bash -lc 'export SQLCMDPASSWORD="$SA_PASSWORD"; if [ -x /opt/mssql-tools18/bin/sqlcmd ]; then /opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -d EKYC_ICICI -l 10 -t 30 -b -h -1 -W; else /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -d EKYC_ICICI -l 10 -t 30 -b -h -1 -W; fi' | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Source SQL failed (exit $LASTEXITCODE)." }
}

function Invoke-Warehouse([string]$Sql) {
    $rows = "SET query_timeout = 15; $Sql" | docker exec -i mbs-starrocks-fe mysql --connect-timeout=5 --batch --skip-column-names -h 127.0.0.1 -P 9030 -u root
    if ($LASTEXITCODE -ne 0) { throw "Warehouse query failed (exit $LASTEXITCODE)." }
    return $rows
}

function Get-WarehouseCount([string]$Sql) {
    $rows = @(Invoke-Warehouse $Sql)
    if ($rows.Count -ne 1 -or $rows[0] -notmatch '^\d+$') { throw 'Expected one numeric warehouse count.' }
    return [long]$rows[0]
}

function Get-AirflowCount([string]$Sql) {
    $rows = @($Sql | docker exec -i -e 'PGOPTIONS=-c statement_timeout=15000' -e PGCONNECT_TIMEOUT=10 mbs-airflow-db bash -lc 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -t -A -v ON_ERROR_STOP=1')
    if ($LASTEXITCODE -ne 0 -or $rows.Count -ne 1 -or $rows[0].Trim() -notmatch '^\d+$') { throw 'Cannot read Airflow metadata.' }
    return [long]$rows[0].Trim()
}

function Set-DagState([string]$Action) {
    docker exec mbs-airflow-scheduler timeout -k 15 120 airflow dags $Action mbs_daily_operations_report *> (Join-Path $evidenceDir "dag-$Action.log")
    if ($LASTEXITCODE -ne 0) { throw "Airflow DAG $Action failed (exit $LASTEXITCODE)." }
}

function Wait-For([string]$Stage, [scriptblock]$Probe, [switch]$CheckIngestion) {
    $deadline = $timer.Elapsed.TotalSeconds + $TimeoutSeconds
    Write-Host "Waiting for $Stage (up to $TimeoutSeconds seconds)..."
    do {
        if ($CheckIngestion) {
            & (Join-Path $PSScriptRoot '../connectors/assert_running.ps1') -Names @('mbs-sqlserver-cdc', 'mbs-iceberg-customer-lead-raw-sink')
        }
        if (& $Probe) { Add-Checkpoint $Stage; return }
        if ($timer.Elapsed.TotalSeconds -ge $deadline) { throw "Timed out waiting for $Stage." }
        Start-Sleep -Seconds $PollSeconds
    } while ($true)
}

function Build-Report([string]$Stage) {
    $log = Join-Path $evidenceDir "$Stage.log"
    docker exec -w /opt/airflow/dbt -e STARROCKS_DBT_HOST=starrocks-fe -e DBT_PROFILES_DIR=/opt/airflow/dbt mbs-airflow-scheduler timeout -k 15 $BuildTimeoutSeconds /home/airflow/.local/bin/dbt run --select silver_customer_lead_consolidated gold_daily_operations_report *> $log
    if ($LASTEXITCODE -ne 0) { throw "$Stage failed (exit $LASTEXITCODE). See $log" }
    Add-Checkpoint $Stage
}

function Assert-CurrentLead([string]$City) {
    $sql = @"
SELECT 'silver', COUNT(*), COALESCE(SUM(CASE WHEN destination_city='$City' THEN 1 ELSE 0 END),0)
FROM default_catalog.analytics.silver_customer_lead_consolidated WHERE source_table='Customer_Lead' AND order_number='$tag'
UNION ALL
SELECT 'gold', COUNT(*), COALESCE(SUM(CASE WHEN destination_city='$City' THEN 1 ELSE 0 END),0)
FROM default_catalog.analytics.gold_daily_operations_report WHERE order_number='$tag';
"@
    $rows = @(Invoke-Warehouse $sql)
    if ($rows.Count -ne 2) { throw 'Incomplete current-lead verification.' }
    foreach ($row in $rows) {
        $parts = $row -split "`t"
        if ($parts.Count -ne 3 -or $parts[0] -notin @('silver', 'gold') -or $parts[1] -ne '1' -or $parts[2] -ne '1') {
            throw "Expected exactly one $City fixture in both Silver and Gold; got $row"
        }
    }
}

function Assert-Deleted([string]$Stage) {
    & (Join-Path $PSScriptRoot 'test_cdc_deleted_lead.ps1') -Tag $tag *> (Join-Path $evidenceDir "$Stage.log")
    Add-Checkpoint $Stage
}

function Remove-SourceFixture([switch]$RequireOne) {
    $guard = if ($RequireOne) { "IF @@ROWCOUNT <> 1 THROW 50002, 'Expected one owned fixture row', 1;" } else { '' }
    Invoke-SourceSql "SET NOCOUNT ON; DELETE FROM dbo.Customer_Lead WHERE RefNumber='$tag' AND SourceSystem='CDC-SMOKE-CHECK'; $guard"
}

function Wait-ForDelete {
    Wait-For 'raw_delete' { (Get-WarehouseCount "SELECT COUNT(*) FROM iceberg_catalog.raw.customer_lead_cdc_connect WHERE op='d' AND before.RefNumber='$tag';") -gt 0 } -CheckIngestion
}

Push-Location $repoRoot
try {
    # One local check owns scheduling/rebuilds at a time; no additional service needed.
    $lock = [IO.File]::Open((Join-Path $repoRoot '.runtime/cdc-smoke.lock'), [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    Write-Host "Synthetic fixture: $tag"
    Write-Host "Evidence: $evidenceDir"
    Add-Checkpoint 'started'
    & (Join-Path $PSScriptRoot 'day3_verify_iceberg_sink_plugin.ps1') *> (Join-Path $evidenceDir 'preflight.log')
    Invoke-SourceSql 'SET NOCOUNT ON; SELECT 1;'
    Add-Checkpoint 'preflight'

    $wasPaused = (Get-AirflowCount "SELECT CASE WHEN is_paused THEN 1 ELSE 0 END FROM dag WHERE dag_id='mbs_daily_operations_report';") -eq 1
    $summary.dag_was_paused = $wasPaused
    if (-not $wasPaused) { Set-DagState 'pause' }
    if ((Get-AirflowCount "SELECT COUNT(*) FROM dag_run WHERE dag_id='mbs_daily_operations_report' AND state='queued';") -gt 0) {
        throw 'A queued report run exists. Let it finish before retrying; this check does not cancel existing runs.'
    }
    Wait-For 'scheduled_runs_drained' { (Get-AirflowCount "SELECT COUNT(*) FROM dag_run WHERE dag_id='mbs_daily_operations_report' AND state='running';") -eq 0 }

    $fixtureMayExist = $true
    $summary.fixture_removed = $false
    Invoke-SourceSql @"
SET NOCOUNT ON; SET XACT_ABORT ON;
IF EXISTS (SELECT 1 FROM dbo.Customer_Lead WHERE RefNumber='$tag') THROW 50001,'Fixture tag already exists',1;
INSERT INTO dbo.Customer_Lead
 (ORDER_NUMBER,DESTINATION_CITY,PINCODE,STATE,Bank_Status,DTCreatedDate,DTUpdateDate,SR_Status,ChannelCode,RefNumber,SourceSystem,BankId,ServiceTypeID,Sub_Status)
VALUES ('$tag','CDC Smoke Initial','400001','Maharashtra','OPEN',SYSUTCDATETIME(),SYSUTCDATETIME(),1,'DSB','$tag','CDC-SMOKE-CHECK',3,1,0);
"@
    Add-Checkpoint 'source_insert'
    if ($FailAfterInsert) { throw 'Intentional diagnostic failure after insert.' }
    Wait-For 'raw_insert' { (Get-WarehouseCount "SELECT COUNT(*) FROM iceberg_catalog.raw.customer_lead_cdc_connect WHERE op='c' AND after.RefNumber='$tag' AND after.DESTINATION_CITY='CDC Smoke Initial';") -gt 0 } -CheckIngestion
    Build-Report 'insert_build'
    Assert-CurrentLead 'CDC Smoke Initial'
    Add-Checkpoint 'insert_verified'

    Invoke-SourceSql "SET NOCOUNT ON; UPDATE dbo.Customer_Lead SET DESTINATION_CITY='CDC Smoke Updated',DTUpdateDate=SYSUTCDATETIME() WHERE RefNumber='$tag' AND SourceSystem='CDC-SMOKE-CHECK'; IF @@ROWCOUNT <> 1 THROW 50003,'Expected one owned fixture row',1;"
    Add-Checkpoint 'source_update'
    Wait-For 'raw_update' { (Get-WarehouseCount "SELECT COUNT(*) FROM iceberg_catalog.raw.customer_lead_cdc_connect WHERE op='u' AND after.RefNumber='$tag' AND after.DESTINATION_CITY='CDC Smoke Updated';") -gt 0 } -CheckIngestion
    Build-Report 'update_build'
    Assert-CurrentLead 'CDC Smoke Updated'
    Add-Checkpoint 'update_verified'

    Remove-SourceFixture -RequireOne
    Add-Checkpoint 'source_delete'
    Wait-ForDelete
    Build-Report 'delete_build'
    Assert-Deleted 'delete_verified'
    Build-Report 'repeat_build'
    Assert-Deleted 'repeat_verified'
    $fixtureMayExist = $false
    $summary.fixture_removed = $true
    $completed = $true
}
catch {
    $summary.failure = $_.Exception.Message
    Add-Checkpoint 'failed' 'failed' $summary.failure
}
finally {
    if ($fixtureMayExist) {
        try {
            Remove-SourceFixture
            Add-Checkpoint 'cleanup_source'
            Wait-ForDelete
            Build-Report 'cleanup_build'
            Assert-Deleted 'cleanup_verified'
            $summary.fixture_removed = $true
        }
        catch {
            $cleanupErrors += $_.Exception.Message
            Add-Checkpoint 'cleanup_failed' 'failed' $_.Exception.Message
        }
    }
    if ($null -ne $wasPaused) {
        try {
            if (-not $wasPaused) { Set-DagState 'unpause' }
            $actualPaused = (Get-AirflowCount "SELECT CASE WHEN is_paused THEN 1 ELSE 0 END FROM dag WHERE dag_id='mbs_daily_operations_report';") -eq 1
            if ($actualPaused -ne $wasPaused) { throw 'Original DAG pause state was not restored.' }
            $summary.dag_restored = $true
            Add-Checkpoint 'scheduling_restored'
        }
        catch {
            $summary.dag_restored = $false
            $cleanupErrors += $_.Exception.Message
            Add-Checkpoint 'restore_failed' 'failed' $_.Exception.Message
        }
    }
    $summary.cleanup_errors = @($cleanupErrors)
    $summary.status = if ($completed -and -not $summary.failure -and $cleanupErrors.Count -eq 0) { 'passed' } else { 'failed' }
    Save-Evidence
    if ($null -ne $lock) { $lock.Dispose() }
    Pop-Location
}

if ($summary.status -ne 'passed') {
    throw "CDC smoke check FAILED. $($summary.failure) Cleanup errors: $($cleanupErrors -join '; '). Evidence: $evidenceDir"
}
Write-Host "CDC smoke check PASSED: insert, update, delete and repeated rebuild. Evidence: $evidenceDir"
