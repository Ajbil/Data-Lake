param(
    [ValidatePattern('^[A-Za-z0-9_-]{0,100}$')][string]$Tag = "",
    [ValidateRange(1, 86400)][int]$TimeoutSeconds = 900,
    [ValidateRange(1, 300)][int]$PollSeconds = 5,
    [string]$EnvFile = ".env",
    [string]$SqlContainer = "mbs-sqlserver",
    [string]$DagId = "mbs_daily_operations_report",
    [switch]$SkipAirflowTrigger
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($Tag)) {
    $Tag = "CDC-LATENCY-{0:yyyyMMddHHmmss}" -f (Get-Date)
}

$RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
$ResolvedEnvFile = if ([System.IO.Path]::IsPathRooted($EnvFile)) { $EnvFile } else { Join-Path $RepoRoot $EnvFile }
$EvidenceDir = Join-Path $RepoRoot "screenshots"
$EvidencePath = Join-Path $EvidenceDir "$Tag-report-latency.csv"
New-Item -ItemType Directory -Force -Path $EvidenceDir | Out-Null

function Import-DotEnv {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        throw "Missing env file: $Path"
    }

    Get-Content -Path $Path | ForEach-Object {
        if ($_ -match "^\s*#" -or $_ -notmatch "=") {
            return
        }
        $key, $value = $_ -split "=", 2
        [Environment]::SetEnvironmentVariable($key.Trim(), $value.Trim(), "Process")
    }
}

function Invoke-SqlServer {
    param([string]$Sql)

    $Sql | docker exec -i $SqlContainer bash -lc 'export SQLCMDPASSWORD=$SA_PASSWORD; if [ -x /opt/mssql-tools18/bin/sqlcmd ]; then /opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -l 10 -t 30 -b; elif [ -x /opt/mssql-tools/bin/sqlcmd ]; then /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -l 10 -t 30 -b; else echo sqlcmd_not_found; exit 127; fi'
    if ($LASTEXITCODE -ne 0) {
        throw "SQL Server command failed with exit code $LASTEXITCODE."
    }
}

function Invoke-StarRocks {
    param([string]$Query)

    "SET query_timeout = 15; $Query" | docker exec -i mbs-starrocks-fe bash -lc "mysql --connect-timeout=5 --batch --skip-column-names -h 127.0.0.1 -P 9030 -u root"
    if ($LASTEXITCODE -ne 0) {
        throw "StarRocks query failed with exit code $LASTEXITCODE."
    }
}

function Invoke-StarRocksScalar {
    param([string]$Query)

    $raw = Invoke-StarRocks -Query $Query
    return ($raw | Select-Object -First 1)
}

function Add-Checkpoint {
    param(
        [string]$Stage,
        [string]$Details = ""
    )

    $now = Get-Date
    $elapsed = [math]::Round(($now - $script:StartTime).TotalSeconds, 3)
    $delta = if ($null -eq $script:LastCheckpointAt) { 0 } else { [math]::Round(($now - $script:LastCheckpointAt).TotalSeconds, 3) }
    $script:LastCheckpointAt = $now

    $script:Checkpoints.Add([pscustomobject]@{
        tag = $Tag
        stage = $Stage
        observed_at_local = $now.ToString("o")
        delta_from_previous_seconds = $delta
        elapsed_seconds = $elapsed
        details = $Details
    })
    $script:Checkpoints | Export-Csv -NoTypeInformation -Path $EvidencePath

    if ([string]::IsNullOrWhiteSpace($Details)) {
        Write-Host ("[{0:n3}s] {1}" -f $elapsed, $Stage)
    } else {
        Write-Host ("[{0:n3}s] {1} - {2}" -f $elapsed, $Stage, $Details)
    }
}

function Wait-Until {
    param(
        [string]$Stage,
        [scriptblock]$Probe,
        [int]$TimeoutSeconds,
        [switch]$CheckConnectors
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $nextProgress = Get-Date
    Write-Host "Waiting for: $Stage (limit ${TimeoutSeconds}s)."
    while ((Get-Date) -lt $deadline) {
        if ((Get-Date) -ge $nextProgress) {
            if ($CheckConnectors) {
                & $script:AssertConnectors -Names $script:ReportConnectors
            }
            $remaining = [math]::Max(0, [math]::Ceiling(($deadline - (Get-Date)).TotalSeconds))
            Write-Host "Still waiting for: $Stage; ${remaining}s remaining. Evidence: $EvidencePath"
            $nextProgress = (Get-Date).AddSeconds(30)
        }
        $result = & $Probe
        if ($result) {
            $details = if ($result -is [string]) { $result } else { "" }
            Add-Checkpoint -Stage $Stage -Details $details
            return
        }
        Start-Sleep -Seconds $PollSeconds
    }
    throw "Timed out waiting for stage '$Stage' after $TimeoutSeconds seconds. Completed checkpoints are saved in $EvidencePath. Check health:iceberg and the writer logs before inserting another test row."
}

Import-DotEnv -Path $ResolvedEnvFile

$topicPrefix = if ($env:KAFKA_TOPIC_PREFIX) { $env:KAFKA_TOPIC_PREFIX } else { "mbs_poc" }
$customerLeadTopic = "$topicPrefix.EKYC_ICICI.dbo.Customer_Lead"
$airflowRunId = "latency_$($Tag.Replace('-', '_'))"
$script:Checkpoints = New-Object System.Collections.Generic.List[object]
$script:StartTime = Get-Date
$script:LastCheckpointAt = $null
$script:AssertConnectors = Join-Path $RepoRoot "scripts/connectors/assert_running.ps1"
$script:ReportConnectors = @(
    "mbs-sqlserver-cdc",
    "mbs-iceberg-customer-lead-raw-sink",
    "mbs-iceberg-service-request-assign-log-raw-sink",
    "mbs-iceberg-mst-campaign-leads-raw-sink"
)

trap {
    if ($null -ne $script:Checkpoints) {
        Add-Checkpoint -Stage "FAILED" -Details $_.Exception.Message
        Write-Host "Completed checkpoints and failure saved to $EvidencePath"
    }
    throw $_
}

Write-Host "Measuring Daily Operations Report latency for tag: $Tag"
Write-Host "Evidence CSV: $EvidencePath"
Write-Host ""

Write-Host "Checking source and report sink tasks before inserting sample data..."
& $script:AssertConnectors -Names $script:ReportConnectors

$insertSql = @"
USE EKYC_ICICI;
GO

SET NOCOUNT ON;
DECLARE @tag varchar(100) = '$Tag';

INSERT INTO dbo.Customer_Lead
    (ORDER_NUMBER, DESTINATION_CITY, PINCODE, STATE, MOBILE, Bank_Status, DTCreatedDate, DTUpdateDate, SR_Status, ChannelCode, RefNumber, SourceSystem, BankId, ClientName, CustLandMark, ServiceTypeID, Sub_Status)
VALUES
    (@tag, 'Latency Test City', '400001', 'Maharashtra', '9000999999', 'OPEN', SYSUTCDATETIME(), SYSUTCDATETIME(), 1, 'DSB', @tag, 'LATENCY-CHECK', 3, 'ICICI', 'Latency check landmark', 1, 0);

INSERT INTO dbo.ServiceRequestAssignLog
    (ORDER_NUMBER, UserID, StatusID, UpdateStatusDate, Active, AgentId)
VALUES
    (@tag, 'SUP1', 2, SYSUTCDATETIME(), 1, 'AG001');

INSERT INTO dbo.MstCampaignLeads
    (AgentId, OrderNumber, AppointmentDateTime, DtCreatedDate, DtUpdatedDate, status, Remarks, SpecialCampaign, Price)
VALUES
    ('AG001', @tag, DATEADD(HOUR, 1, SYSUTCDATETIME()), SYSUTCDATETIME(), SYSUTCDATETIME(), 1, 'Latency pipeline check', 1, '0');

SELECT @tag AS latency_tag;
GO
"@

Invoke-SqlServer -Sql $insertSql
Add-Checkpoint -Stage "SQL Server source insert" -Details "EKYC_ICICI.dbo.Customer_Lead RefNumber=$Tag"

Wait-Until -Stage "Kafka CDC event visible" -TimeoutSeconds $TimeoutSeconds -CheckConnectors -Probe {
    $cmd = "KAFKA_HEAP_OPTS='-Xms32m -Xmx128m' kafka-console-consumer --bootstrap-server kafka:9092 --topic $customerLeadTopic --from-beginning --timeout-ms 20000 2>/dev/null | grep -a -F -m 1 -- '$Tag' >/dev/null && echo found"
    $result = docker exec mbs-kafka bash -lc $cmd
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace(($result | Out-String))) {
        return $customerLeadTopic
    }
    return $false
}

Wait-Until -Stage "Iceberg raw visible through StarRocks" -TimeoutSeconds $TimeoutSeconds -CheckConnectors -Probe {
    $count = Invoke-StarRocksScalar -Query "SELECT COUNT(*) FROM iceberg_catalog.raw.customer_lead_cdc_connect WHERE after.RefNumber = '$Tag';"
    if (($count -as [int]) -gt 0) {
        return "iceberg_catalog.raw.customer_lead_cdc_connect count=$count"
    }
    return $false
}

if ($SkipAirflowTrigger) {
    Add-Checkpoint -Stage "Airflow trigger skipped" -Details "Waiting for scheduled/manual dbt run to refresh Gold"
} else {
    docker exec mbs-airflow-scheduler bash -lc "airflow dags unpause $DagId >/dev/null 2>&1 || true"
    docker exec mbs-airflow-scheduler bash -lc "airflow dags trigger -r $airflowRunId $DagId"
    if ($LASTEXITCODE -ne 0) {
        throw "Airflow DAG trigger failed with exit code $LASTEXITCODE."
    }
    Add-Checkpoint -Stage "Airflow DAG triggered" -Details "$DagId run_id=$airflowRunId"
}

Wait-Until -Stage "StarRocks Gold visible" -TimeoutSeconds $TimeoutSeconds -Probe {
    $count = Invoke-StarRocksScalar -Query "SELECT COUNT(*) FROM default_catalog.analytics.gold_daily_operations_report WHERE order_number = '$Tag';"
    if (($count -as [int]) -gt 0) {
        return "default_catalog.analytics.gold_daily_operations_report count=$count"
    }
    return $false
}

$goldRowQuery = @"
SELECT
    order_number,
    record_type,
    champaines,
    serviceable_pincode,
    agent_id,
    agent_name,
    source_system
FROM default_catalog.analytics.gold_daily_operations_report
WHERE order_number = '$Tag';
"@

Write-Host "`nGold row:"
Invoke-StarRocks -Query $goldRowQuery

$script:Checkpoints | Export-Csv -NoTypeInformation -Path $EvidencePath

Write-Host "`nLatency summary:"
$script:Checkpoints | Format-Table -AutoSize
Write-Host "`nTotal source-to-gold latency: $([math]::Round(((Get-Date) - $script:StartTime).TotalSeconds, 3)) seconds"
Write-Host "Latency evidence written to $EvidencePath"
