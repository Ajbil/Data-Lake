param(
    [int]$RowsPerSecond = 10,
    [int]$DurationMinutes = 30,
    [int]$DurationSeconds = 0,
    [string]$BatchTag = "",
    [string]$Database = "mbs_poc",
    [string]$SqlContainer = "mbs-sqlserver",
    [string]$EnvFile = ".env"
)

$ErrorActionPreference = "Stop"

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

Import-DotEnv -Path $EnvFile

if ($RowsPerSecond -lt 1) {
    throw "RowsPerSecond must be at least 1."
}

if ($DurationSeconds -lt 0) {
    throw "DurationSeconds cannot be negative."
}

if ($DurationSeconds -eq 0 -and $DurationMinutes -lt 1) {
    throw "DurationMinutes must be at least 1 when DurationSeconds is not provided."
}

if ([string]::IsNullOrWhiteSpace($BatchTag)) {
    $BatchTag = "day6-load-{0:yyyyMMddHHmmss}" -f (Get-Date)
}

$effectiveSeconds = if ($DurationSeconds -gt 0) { $DurationSeconds } else { $DurationMinutes * 60 }
$totalRows = $RowsPerSecond * $effectiveSeconds
$sql = @"
USE [$Database];
SET NOCOUNT ON;

DECLARE @i INT = 1;
DECLARE @agent_count INT = (SELECT COUNT(*) FROM dbo.agents);

WHILE @i <= $totalRows
BEGIN
    DECLARE @agent_id INT = ((@i - 1) % @agent_count) + 1;
    DECLARE @status NVARCHAR(20) =
        CASE
            WHEN @i % 17 = 0 THEN N'REJECTED'
            WHEN @i % 7 = 0 THEN N'PENDING'
            ELSE N'COMPLETED'
        END;
    DECLARE @channel NVARCHAR(20) =
        CASE
            WHEN @i % 3 = 0 THEN N'DIGITAL'
            WHEN @i % 3 = 1 THEN N'BRANCH'
            ELSE N'FIELD'
        END;
    DECLARE @now DATETIME2(3) = SYSUTCDATETIME();

    INSERT INTO dbo.kyc_completions
        (agent_id, customer_reference, kyc_status, completion_channel, completed_at, created_at, updated_at, event_tag)
    VALUES
        (
            @agent_id,
            CONCAT(N'CUST-DAY6-', FORMAT(@i, '000000')),
            @status,
            @channel,
            CASE WHEN @status = N'COMPLETED' THEN @now ELSE NULL END,
            @now,
            @now,
            CONCAT(N'$BatchTag-', FORMAT(@i, '000000'))
        );

    IF @i % $RowsPerSecond = 0
    BEGIN
        RAISERROR('Inserted %d of $totalRows rows for batch $BatchTag', 0, 1, @i) WITH NOWAIT;
        WAITFOR DELAY '00:00:01';
    END;

    SET @i += 1;
END;

SELECT
    '$BatchTag' AS batch_tag,
    $totalRows AS inserted_rows,
    MIN(created_at) AS first_created_at,
    MAX(created_at) AS last_created_at
FROM dbo.kyc_completions
WHERE event_tag LIKE '$BatchTag-%';
"@

Write-Host "Starting Day 6 KYC loader..."
Write-Host "Batch tag: $BatchTag"
Write-Host "Rows/sec:  $RowsPerSecond"
Write-Host "Duration:  $effectiveSeconds second(s)"
Write-Host "Rows:      $totalRows"

$sql | docker exec -i $SqlContainer /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P $env:MSSQL_SA_PASSWORD -C -b
if ($LASTEXITCODE -ne 0) {
    throw "Day 6 loader failed with exit code $LASTEXITCODE."
}

Write-Host "`nDay 6 loader complete."
