SHOW CATALOGS;
SHOW DATABASES FROM iceberg_catalog;
SHOW TABLES FROM iceberg_catalog.raw;

SELECT COUNT(*) AS customer_lead_raw_count
FROM iceberg_catalog.raw.customer_lead_cdc_connect;

SELECT COUNT(*) AS sr_status_update_log_raw_count
FROM iceberg_catalog.raw.sr_status_update_log_cdc_connect;

SELECT COUNT(*) AS campaign_leads_raw_count
FROM iceberg_catalog.raw.mst_campaign_leads_cdc_connect;

SELECT COUNT(*) AS mbs_user_raw_count
FROM iceberg_catalog.raw.mbs_user_cdc_connect;
