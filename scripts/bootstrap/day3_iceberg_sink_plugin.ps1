param(
    [string]$RepoRoot = (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)))
)

$ErrorActionPreference = "Stop"

$pluginRoot = Join-Path $RepoRoot "infra/kafka-connect/plugins/iceberg-sink"
$pomFile = Join-Path $pluginRoot "pom.xml"

if (-not (Test-Path $pomFile)) {
    throw "Missing Iceberg sink plugin pom: $pomFile"
}

New-Item -ItemType Directory -Force -Path $pluginRoot | Out-Null

Write-Host "Downloading Apache Iceberg Kafka Connect sink dependencies into $pluginRoot"
docker run --rm `
    -v "${RepoRoot}:/workspace" `
    -w /workspace `
    maven:3.9-eclipse-temurin-17 `
    mvn -q `
    -f infra/kafka-connect/plugins/iceberg-sink/pom.xml `
    dependency:copy-dependencies `
    "-DoutputDirectory=/workspace/infra/kafka-connect/plugins/iceberg-sink" `
    "-DincludeScope=runtime"

if ($LASTEXITCODE -ne 0) {
    throw "Maven dependency download failed with exit code $LASTEXITCODE."
}

Write-Host "Iceberg sink plugin jars installed under infra/kafka-connect/plugins/iceberg-sink."
