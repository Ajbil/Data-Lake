param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^CDC-FIX-[A-Za-z0-9_-]+$')]
    [string]$Tag
)

$ErrorActionPreference = 'Stop'

# Read-only regression: the dedicated fixture must already have been deleted.
# A real Raw delete is required so an unknown tag cannot falsely pass.
$query = @"
SELECT 'raw_delete', COUNT(*)
FROM iceberg_catalog.raw.customer_lead_cdc_connect
WHERE op = 'd' AND before.RefNumber = '$Tag'
UNION ALL
SELECT 'silver_current', COUNT(*)
FROM default_catalog.analytics.silver_customer_lead_consolidated
WHERE source_table = 'Customer_Lead' AND order_number = '$Tag'
UNION ALL
SELECT 'gold_current', COUNT(*)
FROM default_catalog.analytics.gold_daily_operations_report
WHERE order_number = '$Tag';
"@

$rows = "SET query_timeout = 15; $query" | docker exec -i mbs-starrocks-fe mysql --connect-timeout=5 --batch --skip-column-names -h 127.0.0.1 -P 9030 -u root
if ($LASTEXITCODE -ne 0) { throw 'CDC deletion verification query failed.' }

$counts = @{}
foreach ($row in $rows) {
    $parts = $row -split "`t"
    if ($parts.Count -ne 2 -or $parts[0] -notin @('raw_delete', 'silver_current', 'gold_current')) {
        throw 'Unexpected CDC verification result.'
    }
    $counts[$parts[0]] = [long]$parts[1]
}
if ($counts.Count -ne 3) { throw 'Incomplete CDC verification result.' }

$results = @(
    [pscustomobject]@{ check = 'Raw delete captured'; actual = $counts.raw_delete; passed = ($counts.raw_delete -gt 0) }
    [pscustomobject]@{ check = 'Deleted lead absent from Silver'; actual = $counts.silver_current; passed = ($counts.silver_current -eq 0) }
    [pscustomobject]@{ check = 'Deleted lead absent from Gold'; actual = $counts.gold_current; passed = ($counts.gold_current -eq 0) }
)
$results | Format-Table -AutoSize
if (@($results | Where-Object { -not $_.passed }).Count -gt 0) {
    throw "CDC deletion regression failed for $Tag. Rebuild the models only after Raw has the delete; do not hide the failure by reseeding."
}
Write-Host "CDC deletion regression passed for $Tag."
