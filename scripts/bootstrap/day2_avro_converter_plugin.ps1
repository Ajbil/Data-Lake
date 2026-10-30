param(
    [string]$RepoRoot = (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)))
)

$ErrorActionPreference = "Stop"

$pluginRoot = Join-Path $RepoRoot "infra/kafka-connect/plugins/avro-converter"
$pomFile = Join-Path $pluginRoot "pom.xml"

if (-not (Test-Path $pomFile)) {
    throw "Missing Avro converter plugin pom: $pomFile"
}

New-Item -ItemType Directory -Force -Path $pluginRoot | Out-Null

Write-Host "Downloading Confluent Avro converter dependencies into $pluginRoot"
docker run --rm `
    -v "${RepoRoot}:/workspace" `
    -w /workspace `
    maven:3.9-eclipse-temurin-17 `
    mvn -q `
    -f infra/kafka-connect/plugins/avro-converter/pom.xml `
    dependency:copy-dependencies `
    "-DoutputDirectory=/workspace/infra/kafka-connect/plugins/avro-converter" `
    "-DincludeScope=runtime"

if ($LASTEXITCODE -ne 0) {
    throw "Maven dependency download failed with exit code $LASTEXITCODE."
}

Write-Host "Avro converter jars installed under infra/kafka-connect/plugins/avro-converter."
Write-Host "Restart Kafka Connect so it can load io.confluent.connect.avro.AvroConverter."
