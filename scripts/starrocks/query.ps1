param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Query
)

$ErrorActionPreference = "Stop"

$escapedQuery = $Query.Replace("'", "''")
docker exec mbs-starrocks-fe bash -lc "mysql -h 127.0.0.1 -P 9030 -u root -e '$escapedQuery'"
