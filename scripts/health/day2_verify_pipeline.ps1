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

$minioUser = Read-DotEnvValue -Path $EnvFile -Name "MINIO_ROOT_USER"
$minioPassword = Read-DotEnvValue -Path $EnvFile -Name "MINIO_ROOT_PASSWORD"

Write-Host "`nDebezium connector status:"
Invoke-RestMethod -Uri "http://localhost:8083/connectors/mbs-sqlserver-cdc/status" -TimeoutSec 10 | ConvertTo-Json -Depth 10

Write-Host "`nKafka topics:"
docker exec mbs-kafka kafka-topics --bootstrap-server kafka:9092 --list

Write-Host "`nSchema Registry subjects:"
$subjects = Invoke-RestMethod -Uri "http://localhost:8081/subjects" -TimeoutSec 10
$subjects | ConvertTo-Json -Compress
if (-not $subjects -or $subjects.Count -eq 0) {
    throw "Schema Registry has no subjects. Kafka Connect is not producing Avro-backed schemas yet."
}

Write-Host "`nMinIO buckets:"
docker run --rm --network container:mbs-minio --entrypoint /bin/sh minio/mc:latest -c "mc alias set local http://localhost:9000 $minioUser $minioPassword >/dev/null && mc ls local"

Write-Host "`nIceberg REST catalog health:"
try {
    Invoke-RestMethod -Uri "http://localhost:8181/v1/config" -TimeoutSec 10 | ConvertTo-Json -Depth 10
} catch {
    Write-Host "Iceberg REST config endpoint not ready: $($_.Exception.Message)"
    throw
}

Write-Host "`nDay 2 Debezium and Avro verification complete."
