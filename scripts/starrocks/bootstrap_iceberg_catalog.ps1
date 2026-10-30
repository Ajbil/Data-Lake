param(
    [string]$EnvFile = ".env"
)

$ErrorActionPreference = "Stop"

function Read-DotEnv {
    param([string]$Path)

    $values = @{}
    Get-Content -Path $Path | ForEach-Object {
        if ($_ -match "^\s*#" -or $_ -notmatch "=") {
            return
        }

        $key, $value = $_ -split "=", 2
        $values[$key.Trim()] = $value.Trim()
    }

    return $values
}

if (-not (Test-Path $EnvFile)) {
    throw "Expected $EnvFile to exist. Copy .env.example to .env first."
}

$envValues = Read-DotEnv -Path $EnvFile
$sql = Get-Content -Raw -Path "infra/starrocks/catalogs/create_iceberg_catalog.sql"
foreach ($key in $envValues.Keys) {
    $sql = $sql.Replace("`${$key}", $envValues[$key])
}

Write-Host "Creating StarRocks external Iceberg catalog..."
$sql | docker exec -i mbs-starrocks-fe bash -lc "mysql -h 127.0.0.1 -P 9030 -u root"
if ($LASTEXITCODE -ne 0) {
    throw "StarRocks catalog bootstrap failed with exit code $LASTEXITCODE."
}

Write-Host "StarRocks Iceberg catalog bootstrap complete."
