param(
    [string]$Target = "dev"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path ".\.venv\Scripts\dbt.exe")) {
    throw "dbt is not installed. Run scripts\setup.ps1 bootstrap:day4-dbt first."
}

$env:DBT_PROFILES_DIR = (Resolve-Path ".\dbt").Path
$env:STARROCKS_DBT_HOST = if ($env:STARROCKS_DBT_HOST) { $env:STARROCKS_DBT_HOST } else { "127.0.0.1" }
$env:STARROCKS_MYSQL_PORT = if ($env:STARROCKS_MYSQL_PORT) { $env:STARROCKS_MYSQL_PORT } else { "9030" }
$env:STARROCKS_CATALOG = if ($env:STARROCKS_CATALOG) { $env:STARROCKS_CATALOG } else { "default_catalog" }
$env:STARROCKS_SCHEMA = if ($env:STARROCKS_SCHEMA) { $env:STARROCKS_SCHEMA } else { "analytics" }
$env:STARROCKS_USER = if ($env:STARROCKS_USER) { $env:STARROCKS_USER } else { "root" }
$env:STARROCKS_PASSWORD = if ($env:STARROCKS_PASSWORD) { $env:STARROCKS_PASSWORD } else { "" }

Write-Host "Running dbt debug..."
.\.venv\Scripts\dbt.exe debug --project-dir .\dbt --target $Target
if ($LASTEXITCODE -ne 0) {
    throw "dbt debug failed with exit code $LASTEXITCODE."
}

Write-Host "`nRunning dbt models..."
.\.venv\Scripts\dbt.exe run --project-dir .\dbt --target $Target
if ($LASTEXITCODE -ne 0) {
    throw "dbt run failed with exit code $LASTEXITCODE."
}

Write-Host "`nRunning dbt tests..."
.\.venv\Scripts\dbt.exe test --project-dir .\dbt --target $Target
if ($LASTEXITCODE -ne 0) {
    throw "dbt test failed with exit code $LASTEXITCODE."
}

Write-Host "`ndbt Silver/Gold build complete."
