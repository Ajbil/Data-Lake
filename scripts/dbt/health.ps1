$ErrorActionPreference = "Stop"

$query = @"
SELECT COUNT(*) AS silver_customer_leads_count FROM default_catalog.analytics.silver_customer_lead_consolidated;
SELECT COUNT(*) AS silver_assignment_log_count FROM default_catalog.analytics.silver_service_request_assign_log_consolidated;
SELECT COUNT(*) AS silver_sr_status_log_count FROM default_catalog.analytics.silver_sr_status_update_log_consolidated;
SELECT COUNT(*) AS silver_mbs_user_count FROM default_catalog.analytics.silver_mbs_user;
SELECT COUNT(*) AS gold_daily_operations_report_count FROM default_catalog.analytics.gold_daily_operations_report;
SELECT record_type, COUNT(*) AS lead_count
FROM default_catalog.analytics.gold_daily_operations_report
GROUP BY record_type
ORDER BY record_type;
"@

Write-Host "Checking dbt Silver/Gold tables in StarRocks..."
$query | docker exec -i mbs-starrocks-fe bash -lc "mysql -h 127.0.0.1 -P 9030 -u root"
if ($LASTEXITCODE -ne 0) {
    throw "dbt Silver/Gold verification failed with exit code $LASTEXITCODE."
}

Write-Host "`nDaily Operations Report dbt verification complete."
