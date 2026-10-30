param(
    [string]$EnvFile = ".env"
)

$ErrorActionPreference = "Stop"

Write-Host "Checking Kafka Connect Iceberg sink plugin..."
$plugins = Invoke-RestMethod -Uri "http://localhost:8083/connector-plugins" -TimeoutSec 20
$icebergPlugin = $plugins | Where-Object { $_.class -eq "org.apache.iceberg.connect.IcebergSinkConnector" }
if (-not $icebergPlugin) {
    throw "IcebergSinkConnector is not loaded in Kafka Connect."
}
$icebergPlugin | ConvertTo-Json -Depth 5

Write-Host "`nChecking source and Iceberg sink connector statuses..."
$connectors = @(
    "mbs-iceberg-customer-lead-raw-sink",
    "mbs-iceberg-customer-lead-icici-raw-sink",
    "mbs-iceberg-change-pincode-log-raw-sink",
    "mbs-iceberg-service-request-assign-log-raw-sink",
    "mbs-iceberg-sr-status-update-log-raw-sink",
    "mbs-iceberg-mas-pincode-raw-sink",
    "mbs-iceberg-mas-pincode-mis-hdfc-raw-sink",
    "mbs-iceberg-mst-campaign-leads-raw-sink",
    "mbs-iceberg-mbs-user-raw-sink",
    "mbs-iceberg-customer-lead-archived-raw-sink",
    "mbs-iceberg-customer-lead-purge-details-raw-sink",
    "mbs-iceberg-service-request-assign-log-archieved-raw-sink",
    "mbs-iceberg-service-request-assign-log-purge-details-raw-sink",
    "mbs-iceberg-sr-status-update-log-archieved-raw-sink",
    "mbs-iceberg-sr-status-update-log-purge-details-raw-sink"
)

$registered = Invoke-RestMethod -Uri "http://localhost:8083/connectors" -TimeoutSec 20
$required = @("mbs-sqlserver-cdc") + $connectors
$missing = @($required | Where-Object { $_ -notin $registered })
if ($missing.Count -gt 0) {
    throw "Iceberg plugin is loaded, but $($missing.Count) required connectors are not registered. Check Kafka's persistent log storage, then restore register:source and register:raw. Missing: $($missing -join ', ')"
}

& (Join-Path $PSScriptRoot "../connectors/assert_running.ps1") -Names $required

Write-Host "`nSource and all 15 Iceberg sink connectors have RUNNING tasks."
