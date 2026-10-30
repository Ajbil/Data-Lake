param(
    [Parameter(Mandatory = $true)]
    [string]$FilePath
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $FilePath)) {
    throw "SQL file not found: $FilePath"
}

$sql = Get-Content -Raw -Path $FilePath
$sql | docker exec -i mbs-starrocks-fe bash -lc "mysql -h 127.0.0.1 -P 9030 -u root"
