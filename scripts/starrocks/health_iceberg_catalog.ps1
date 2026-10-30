param(
    [string]$EnvFile = ".env"
)

$ErrorActionPreference = "Stop"

Write-Host "Checking StarRocks FE and BE..."
docker exec mbs-starrocks-fe bash -lc "mysql -h 127.0.0.1 -P 9030 -u root -e 'SHOW FRONTENDS; SHOW BACKENDS;'"
if ($LASTEXITCODE -ne 0) {
    throw "StarRocks FE/BE health check failed with exit code $LASTEXITCODE."
}

Write-Host "`nChecking StarRocks external Iceberg catalog and Raw tables..."
Get-Content -Raw -Path "sql/verification/day4_starrocks_raw_counts.sql" |
    docker exec -i mbs-starrocks-fe bash -lc "mysql -h 127.0.0.1 -P 9030 -u root"
if ($LASTEXITCODE -ne 0) {
    throw "StarRocks Iceberg verification failed with exit code $LASTEXITCODE."
}

Write-Host "`nDay 4 StarRocks + Iceberg verification complete."
