param(
    [string]$EnvFile = ".env"
)

$ErrorActionPreference = "Stop"

function Read-DotEnvValue {
    param(
        [string]$Path,
        [string]$Name
    )

    $line = Get-Content -Path $Path | Where-Object { $_ -match "^$Name=" } | Select-Object -First 1
    if (-not $line) {
        throw "Missing $Name in $Path"
    }

    return ($line -split "=", 2)[1]
}

function Invoke-SqlFile {
    param(
        [string]$Path,
        [string]$Password
    )

    Write-Host "`nRunning $Path"
    Get-Content -Raw -Path $Path | docker exec -i mbs-sqlserver bash -lc "if [ -x /opt/mssql-tools18/bin/sqlcmd ]; then /opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P '$Password'; elif [ -x /opt/mssql-tools/bin/sqlcmd ]; then /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P '$Password'; else echo 'sqlcmd not found in SQL Server container'; exit 127; fi"
    if ($LASTEXITCODE -ne 0) {
        throw "SQL script failed: $Path"
    }
}

if (-not (Test-Path $EnvFile)) {
    throw "Expected $EnvFile to exist. Copy .env.example to .env first."
}

$password = Read-DotEnvValue -Path $EnvFile -Name "MSSQL_SA_PASSWORD"
$files = @(
    "sql/report_sample/001_create_daily_operations_sample.sql",
    "sql/report_sample/002_seed_daily_operations_sample.sql",
    "sql/report_sample/003_enable_daily_operations_cdc.sql",
    "sql/verification/report_sample_counts.sql"
)

foreach ($file in $files) {
    Invoke-SqlFile -Path $file -Password $password
}

Write-Host "`nDaily Operations Report local SQL Server sample is ready."
