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
        [string]$FilePath,
        [string]$Password
    )

    Write-Host "Running $FilePath"
    $sql = Get-Content -Raw -Path $FilePath
    $sql | docker exec -i mbs-sqlserver bash -lc "if [ -x /opt/mssql-tools18/bin/sqlcmd ]; then /opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P '$Password'; elif [ -x /opt/mssql-tools/bin/sqlcmd ]; then /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P '$Password'; else echo 'sqlcmd not found in SQL Server container'; exit 127; fi"
}

if (-not (Test-Path $EnvFile)) {
    throw "Expected $EnvFile to exist. Copy .env.example to .env first."
}

$password = Read-DotEnvValue -Path $EnvFile -Name "MSSQL_SA_PASSWORD"

$files = @(
    "sql/ddl/001_create_database.sql",
    "sql/ddl/002_create_tables.sql",
    "sql/seed/001_seed_agents.sql",
    "sql/seed/002_seed_kyc_completions.sql",
    "sql/cdc/001_enable_cdc.sql",
    "sql/cdc/002_set_retention_7_days.sql"
)

foreach ($file in $files) {
    Invoke-SqlFile -FilePath $file -Password $password
}

Write-Host "Day 1 SQL Server bootstrap complete."
