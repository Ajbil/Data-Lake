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

if (-not (Test-Path $EnvFile)) {
    throw "Expected $EnvFile to exist. Copy .env.example to .env first."
}

$password = Read-DotEnvValue -Path $EnvFile -Name "MSSQL_SA_PASSWORD"
$sql = Get-Content -Raw -Path "sql/security/002_create_debezium_login.sql"

$sql | docker exec -i mbs-sqlserver bash -lc "if [ -x /opt/mssql-tools18/bin/sqlcmd ]; then /opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P '$password'; elif [ -x /opt/mssql-tools/bin/sqlcmd ]; then /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P '$password'; else echo 'sqlcmd not found in SQL Server container'; exit 127; fi"

Write-Host "Day 2 Debezium SQL Server login bootstrap complete."
