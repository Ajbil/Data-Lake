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
$minioBucket = Read-DotEnvValue -Path $EnvFile -Name "MINIO_BUCKET"

Write-Host "`nIceberg REST namespaces:"
Invoke-RestMethod -Uri "http://localhost:8181/v1/namespaces" -TimeoutSec 10 | ConvertTo-Json -Depth 10

Write-Host "`nMinIO warehouse objects:"
docker run --rm --network container:mbs-minio --entrypoint /bin/sh minio/mc:latest -c "mc alias set local http://localhost:9000 $minioUser $minioPassword >/dev/null && mc ls --recursive local/$minioBucket/warehouse/raw | tail -40"

Write-Host "`nDay 3 Raw Iceberg verification complete."
