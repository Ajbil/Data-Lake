param(
    [string]$Tag = "",
    [int]$TimeoutSeconds = 600,
    [ValidateSet("none", "local", "airflow")]
    [string]$TransformMode = "airflow",
    [string]$Database = "mbs_poc",
    [string]$SqlContainer = "mbs-sqlserver",
    [string]$EnvFile = ".env"
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($Tag)) {
    $Tag = "day6-latency-{0:yyyyMMddHHmmss}" -f (Get-Date)
}

$RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
$ResolvedEnvFile = if ([System.IO.Path]::IsPathRooted($EnvFile)) { $EnvFile } else { Join-Path $RepoRoot $EnvFile }
$EvidenceDir = Join-Path $RepoRoot "screenshots"
$EvidencePath = Join-Path $EvidenceDir "$Tag-latency.csv"
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

Import-DotEnv -Path $ResolvedEnvFile

$checkpoints = New-Object System.Collections.Generic.List[object]

function Add-Checkpoint {
    param([string]$Stage)

    $now = Get-Date
    $checkpoints.Add([pscustomobject]@{
        tag = $Tag
        stage = $Stage
        observed_at_local = $now.ToString("o")
        elapsed_seconds = [math]::Round(($now - $script:StartTime).TotalSeconds, 3)
    })
    Write-Host ("[{0:n3}s] {1}" -f (($now - $script:StartTime).TotalSeconds), $Stage)
}

function Invoke-StarRocksScalar {
    param([string]$Query)

    $escaped = $Query.Replace("'", "'\''")
    $raw = docker exec mbs-starrocks-fe bash -lc "mysql --batch --skip-column-names -h 127.0.0.1 -P 9030 -u root -e '$escaped'"
    if ($LASTEXITCODE -ne 0) {
        return $null
    }
    return ($raw | Select-Object -First 1)
}

function Wait-Until {
    param(
        [string]$Stage,
        [scriptblock]$Probe,
        [int]$TimeoutSeconds
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        if (& $Probe) {
            Add-Checkpoint -Stage $Stage
            return
        }
        Start-Sleep -Seconds 5
    }
    throw "Timed out waiting for stage '$Stage' after $TimeoutSeconds seconds."
}

$script:StartTime = Get-Date
Write-Host "Measuring Day 6 tagged-row latency for $Tag"

$insertSql = @"
USE [$Database];
SET NOCOUNT ON;

DECLARE @now DATETIME2(3) = SYSUTCDATETIME();
INSERT INTO dbo.kyc_completions
    (agent_id, customer_reference, kyc_status, completion_channel, completed_at, created_at, updated_at, event_tag)
VALUES
    (1, N'CUST-$Tag', N'COMPLETED', N'DIGITAL', @now, @now, @now, N'$Tag');

SELECT event_tag, created_at FROM dbo.kyc_completions WHERE event_tag = N'$Tag';
"@

$insertSql | docker exec -i $SqlContainer /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P $env:MSSQL_SA_PASSWORD -C -b
if ($LASTEXITCODE -ne 0) {
    throw "SQL Server tagged insert failed with exit code $LASTEXITCODE."
}
Add-Checkpoint -Stage "SQL Server insert"

Wait-Until -Stage "Kafka topic" -TimeoutSeconds $TimeoutSeconds -Probe {
    $cmd = "kafka-console-consumer --bootstrap-server kafka:9092 --topic mbs_poc.mbs_poc.dbo.kyc_completions --from-beginning --timeout-ms 5000 2>/dev/null | grep '$Tag' | head -n 1"
    $result = docker exec mbs-kafka bash -lc $cmd
    return $LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace(($result | Out-String))
}

Wait-Until -Stage "Iceberg Raw visible in StarRocks" -TimeoutSeconds $TimeoutSeconds -Probe {
    $count = Invoke-StarRocksScalar -Query "SELECT COUNT(*) FROM iceberg_catalog.raw.kyc_completions_cdc_connect WHERE after.event_tag = '$Tag';"
    return [int]$count -gt 0
}

if ($TransformMode -eq "local") {
    & (Join-Path $RepoRoot "scripts/dbt/run.ps1")
    if ($LASTEXITCODE -ne 0) {
        throw "Local dbt transform failed."
    }
    Add-Checkpoint -Stage "dbt local run/test complete"
} elseif ($TransformMode -eq "airflow") {
    $runDate = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss")
    docker exec mbs-airflow-scheduler bash -lc "airflow dags test mbs_dbt_silver_gold $runDate"
    if ($LASTEXITCODE -ne 0) {
        throw "Airflow dbt DAG test failed."
    }
    Add-Checkpoint -Stage "Airflow dbt DAG complete"
}

Wait-Until -Stage "Silver visible" -TimeoutSeconds $TimeoutSeconds -Probe {
    $count = Invoke-StarRocksScalar -Query "SELECT COUNT(*) FROM default_catalog.analytics.silver_kyc_completions WHERE event_tag = '$Tag';"
    return [int]$count -gt 0
}

Wait-Until -Stage "Gold visible" -TimeoutSeconds $TimeoutSeconds -Probe {
    $count = Invoke-StarRocksScalar -Query "SELECT COUNT(*) FROM default_catalog.analytics.fact_kyc_completions WHERE event_tag = '$Tag';"
    return [int]$count -gt 0
}

Add-Checkpoint -Stage "PowerBI refresh pending manual validation"

$checkpoints | Export-Csv -NoTypeInformation -Path $EvidencePath
Write-Host "`nLatency evidence written to $EvidencePath"
$checkpoints | Format-Table -AutoSize
