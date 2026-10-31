param(
    [Parameter(Position = 0)]
    [string]$Command = "help"
)

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$ComposeFile = Join-Path $RepoRoot "infra/docker-compose/docker-compose.yml"
$EnvFile = Join-Path $RepoRoot ".env"
$EnvExample = Join-Path $RepoRoot ".env.example"

function Show-Help {
    Write-Host @"
MBS Data Lake POC command runner

Usage:
  .\scripts\setup.ps1 <command>

Commands:
  help            Show this help.
  init            Create .env from .env.example if .env does not exist.
  start           Start the Docker Compose POC services.
  ps              Show Docker service status.
  bootstrap:local-sql
                  Create the legacy local SQL Server sample database, seed data, CDC, and retention.
  bootstrap:report-sample
                  Create local DSB Daily Operations Report sample databases, seed data, and CDC.
  bootstrap:source-login
                  Create the Debezium SQL Server reader login when using local SQL Server.
  plugin:avro    Download the Confluent Avro converter for Schema Registry.
  bootstrap:python
                  Create/update the local Python runtime for fallback tooling.
  plugin:iceberg  Download the Apache Iceberg Kafka Connect sink plugin jars.
  bootstrap:starrocks
                  Create the StarRocks external Iceberg catalog.
  bootstrap:dbt  Install dbt-starrocks dependencies.
  bootstrap:airflow
                  Build Airflow and start its metadata DB and scheduler; UI is optional.
  load:legacy    Legacy synthetic KYC load harness for the original local smoke dataset.
  latency:legacy Legacy synthetic KYC latency harness for the original local smoke dataset.
  latency:report Measure Daily Operations Report source-to-Gold latency with a tagged CDC row.
  failure:legacy-safe
                  Run safe failure scenarios for Kafka Connect, schema change, and StarRocks BE restart.
  register:source Register the Debezium SQL Server source connector.
  register:raw    Register Iceberg Raw sink connectors.
  health:services Check Docker service status and platform endpoints.
  health:source   Check Debezium, Kafka topics, MinIO bucket, and Iceberg REST.
  health:raw      Verify Raw Iceberg namespaces and MinIO warehouse files.
  health:iceberg  Verify Iceberg sink plugin and connector tasks.
  health:starrocks
                  Verify StarRocks FE/BE and Raw Iceberg queries.
  run:dbt         Build and test dbt Silver/Gold models.
  health:dbt      Verify dbt Silver/Gold row counts.
  test:cdc        Run the isolated insert/update/delete/rebuild smoke check.
  health:airflow  Verify DAG discovery and wait for a scheduler-managed dbt run.
  stop            Stop Docker Compose services without deleting volumes.

Typical report flow:
  .\scripts\setup.ps1 init
  .\scripts\setup.ps1 start
  .\scripts\setup.ps1 bootstrap:report-sample
  .\scripts\setup.ps1 plugin:avro
  .\scripts\setup.ps1 register:source
  .\scripts\setup.ps1 health:source
  .\scripts\setup.ps1 plugin:iceberg
  .\scripts\setup.ps1 register:raw
  .\scripts\setup.ps1 health:iceberg
  .\scripts\setup.ps1 health:raw
  .\scripts\setup.ps1 bootstrap:starrocks
  .\scripts\setup.ps1 health:starrocks
  .\scripts\setup.ps1 bootstrap:dbt
  .\scripts\setup.ps1 run:dbt
  .\scripts\setup.ps1 health:dbt
  .\scripts\setup.ps1 bootstrap:airflow
  .\scripts\setup.ps1 health:airflow
  .\scripts\setup.ps1 latency:day6
"@
}

function Assert-EnvFile {
    if (-not (Test-Path $EnvFile)) {
        throw "Missing .env. Run '.\scripts\setup.ps1 init' first."
    }
}

Push-Location $RepoRoot
try {
    switch ($Command) {
        "help" {
            Show-Help
        }
        "init" {
            if (Test-Path $EnvFile) {
                Write-Host ".env already exists; leaving it unchanged."
            } else {
                Copy-Item -Path $EnvExample -Destination $EnvFile
                Write-Host "Created .env from .env.example."
            }
        }
        "start" {
            Assert-EnvFile
            & (Join-Path $RepoRoot "scripts/health/assert_catalog_storage.ps1")
            & (Join-Path $RepoRoot "scripts/health/assert_kafka_storage.ps1")
            docker compose --env-file $EnvFile -f $ComposeFile up -d
        }
        "ps" {
            Assert-EnvFile
            docker compose --env-file $EnvFile -f $ComposeFile ps
        }
        { $_ -in @("bootstrap:local-sql", "bootstrap:day1") } {
            Assert-EnvFile
            & (Join-Path $RepoRoot "scripts/bootstrap/day1_sqlserver.ps1") -EnvFile $EnvFile
        }
        { $_ -in @("bootstrap:source-login", "bootstrap:day2") } {
            Assert-EnvFile
            & (Join-Path $RepoRoot "scripts/bootstrap/day2_sqlserver_debezium_user.ps1") -EnvFile $EnvFile
        }
        "bootstrap:report-sample" {
            Assert-EnvFile
            & (Join-Path $RepoRoot "scripts/bootstrap/report_sample_sqlserver.ps1") -EnvFile $EnvFile
        }
        "plugin:avro" {
            Assert-EnvFile
            & (Join-Path $RepoRoot "scripts/bootstrap/day2_avro_converter_plugin.ps1") -RepoRoot $RepoRoot
        }
        { $_ -in @("bootstrap:python", "bootstrap:day3") } {
            Assert-EnvFile
            & (Join-Path $RepoRoot "scripts/bootstrap/day3_python_env.ps1") -RepoRoot $RepoRoot
        }
        "plugin:iceberg" {
            Assert-EnvFile
            & (Join-Path $RepoRoot "scripts/bootstrap/day3_iceberg_sink_plugin.ps1") -RepoRoot $RepoRoot
        }
        { $_ -in @("bootstrap:day4-starrocks", "bootstrap:starrocks") } {
            Assert-EnvFile
            & (Join-Path $RepoRoot "scripts/starrocks/bootstrap_iceberg_catalog.ps1") -EnvFile $EnvFile
        }
        { $_ -in @("bootstrap:day4-dbt", "bootstrap:dbt") } {
            & (Join-Path $RepoRoot "scripts/dbt/bootstrap.ps1")
        }
        "bootstrap:airflow" {
            Assert-EnvFile
            & (Join-Path $RepoRoot "scripts/airflow/bootstrap.ps1") -EnvFile $EnvFile
        }
        { $_ -in @("register:source", "register:day2") } {
            Assert-EnvFile
            & (Join-Path $RepoRoot "scripts/connectors/register_debezium_day2.ps1") -EnvFile $EnvFile
        }
        { $_ -in @("register:raw", "register:day3") } {
            Assert-EnvFile
            & (Join-Path $RepoRoot "scripts/connectors/register_iceberg_day3.ps1") -EnvFile $EnvFile
        }
        { $_ -in @("health:services", "health:day1") } {
            Assert-EnvFile
            & (Join-Path $RepoRoot "scripts/health/day1_services.ps1")
            & (Join-Path $RepoRoot "scripts/health/day1_verify_sqlserver.ps1") -EnvFile $EnvFile
        }
        { $_ -in @("health:source", "health:day2") } {
            Assert-EnvFile
            & (Join-Path $RepoRoot "scripts/health/day2_verify_pipeline.ps1") -EnvFile $EnvFile
        }
        { $_ -in @("health:raw", "health:day3") } {
            Assert-EnvFile
            & (Join-Path $RepoRoot "scripts/health/day3_verify_iceberg_raw.ps1") -EnvFile $EnvFile
        }
        "health:iceberg" {
            Assert-EnvFile
            & (Join-Path $RepoRoot "scripts/health/day3_verify_iceberg_sink_plugin.ps1") -EnvFile $EnvFile
        }
        { $_ -in @("health:day4-starrocks", "health:starrocks") } {
            Assert-EnvFile
            & (Join-Path $RepoRoot "scripts/starrocks/health_iceberg_catalog.ps1") -EnvFile $EnvFile
        }
        { $_ -in @("run:day4-dbt", "run:dbt") } {
            & (Join-Path $RepoRoot "scripts/dbt/run.ps1")
        }
        { $_ -in @("health:day4-dbt", "health:dbt") } {
            Assert-EnvFile
            & (Join-Path $RepoRoot "scripts/dbt/health.ps1")
        }
        "health:airflow" {
            Assert-EnvFile
            & (Join-Path $RepoRoot "scripts/airflow/health.ps1") -EnvFile $EnvFile
        }
        "test:cdc" {
            Assert-EnvFile
            & (Join-Path $RepoRoot "scripts/health/test_cdc_pipeline.ps1")
        }
        { $_ -in @("load:legacy", "load:day6") } {
            Assert-EnvFile
            & (Join-Path $RepoRoot "loader/kyc_load.ps1") -EnvFile $EnvFile
        }
        { $_ -in @("latency:legacy", "latency:day6") } {
            Assert-EnvFile
            & (Join-Path $RepoRoot "scripts/latency/measure.ps1") -EnvFile $EnvFile
        }
        { $_ -in @("latency:report", "latency:daily-operations") } {
            Assert-EnvFile
            & (Join-Path $RepoRoot "scripts/latency/report_flow.ps1") -EnvFile $EnvFile
        }
        { $_ -in @("failure:legacy-safe", "failure:day6-safe") } {
            Assert-EnvFile
            & (Join-Path $RepoRoot "scripts/failure/run_safe.ps1") -EnvFile $EnvFile
        }
        "stop" {
            Assert-EnvFile
            docker compose --env-file $EnvFile -f $ComposeFile stop
        }
        default {
            Show-Help
            throw "Unknown command: $Command"
        }
    }
}
finally {
    Pop-Location
}
