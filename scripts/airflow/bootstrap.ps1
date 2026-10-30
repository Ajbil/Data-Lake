param(
    [string]$EnvFile = ".env"
)

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
$ComposeFile = Join-Path $RepoRoot "infra/docker-compose/docker-compose.yml"
$ResolvedEnvFile = if ([System.IO.Path]::IsPathRooted($EnvFile)) { $EnvFile } else { Join-Path $RepoRoot $EnvFile }

if (-not (Test-Path $ResolvedEnvFile)) {
    throw "Missing .env. Run scripts\setup.ps1 init first."
}

Push-Location $RepoRoot
try {
    & (Join-Path $RepoRoot "scripts/health/assert_catalog_storage.ps1")
    Write-Host "Building Airflow image with dbt-starrocks..."
    docker compose --env-file $ResolvedEnvFile -f $ComposeFile build airflow-init airflow-webserver airflow-scheduler
    if ($LASTEXITCODE -ne 0) {
        throw "Airflow image build failed with exit code $LASTEXITCODE."
    }

    Write-Host "`nStarting Airflow metadata DB, init, and scheduler..."
    docker compose --env-file $ResolvedEnvFile -f $ComposeFile up -d airflow-db airflow-init airflow-scheduler
    if ($LASTEXITCODE -ne 0) {
        throw "Airflow startup failed with exit code $LASTEXITCODE."
    }

    Write-Host "`nAirflow bootstrap complete. The optional UI remains off; start airflow-webserver explicitly when needed."
}
finally {
    Pop-Location
}
