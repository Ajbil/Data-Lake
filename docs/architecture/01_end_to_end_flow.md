# End-to-End Flow

## Flow Summary

```text
SQL Server CDC -> Debezium -> Kafka Avro -> Kafka Connect Iceberg sink
-> Iceberg Raw on MinIO -> StarRocks -> dbt Silver/Gold
-> Airflow every 5 minutes -> PowerBI Daily Operations Report
```

The POC now targets the client DSB-SahiBnk Daily Operations Report. It validates whether source changes from `EKYC_ICICI` and `EKYC_ICICI_Archived` on the DSB-SahiBnk SQL Server can land in Raw Iceberg, be rebuilt into the report's Silver view equivalents, and produce `gold_daily_operations_report` for PowerBI within the 5-minute dbt schedule.

## Stage Details

| Order | Stage | Why selected | Receives from | Sends to | Working proof |
| --- | --- | --- | --- | --- | --- |
| 1 | SQL Server CDC | Native change capture for the client SQL Server source. | DSB-SahiBnk `EKYC_ICICI` tables | Debezium | CDC-enabled tables have change metadata |
| 2 | Debezium | Proven SQL Server CDC connector with snapshots and schema history. | SQL Server CDC/log metadata | Kafka Connect Avro converters | Connector status is `RUNNING` |
| 3 | Kafka | Durable replay buffer and operational visibility. | Debezium | Kafka Connect Iceberg sink | DSB topics exist and offsets advance |
| 4 | Schema Registry | Versioned Avro contracts for each source table. | Kafka Connect Avro converters | Consumers and sinks | Subjects exist for DSB CDC topics |
| 5 | Kafka Connect Iceberg sink | Declarative table-to-Raw ingestion. | Kafka topics | Iceberg Raw tables | Parquet and metadata files appear in MinIO |
| 6 | MinIO | Self-hosted S3-compatible object storage for POC. | Iceberg writers | Iceberg catalog and StarRocks | `lakehouse` bucket contains warehouse objects |
| 7 | Iceberg REST catalog | Engine-neutral metadata catalog and schema evolution. | Iceberg writers | StarRocks/dbt | Catalog lists Raw tables |
| 8 | StarRocks | Fast SQL layer and MySQL protocol target for BI. | Iceberg Raw and dbt tables | dbt and PowerBI | Raw/Silver/Gold `COUNT(*)` queries work |
| 9 | dbt | Version-controlled report transformations and tests. | StarRocks Raw | Silver and Gold models | `dbt run` and `dbt test` succeed |
| 10 | Airflow | 5-minute scheduler for dbt. | Schedule and dbt project | StarRocks/dbt execution | DAG succeeds |
| 11 | PowerBI | Business validation surface. | StarRocks Gold | Dashboard/report | Daily Operations Report refreshes |

## Raw CDC Design

Raw Iceberg tables preserve the Debezium envelope:

- `op`
- `before`
- `after`
- `source`
- source event timestamp
- Debezium ingestion timestamp

Raw is append-only and audit-oriented. Silver owns current-state interpretation, union logic, and report shaping.

## DSB Raw Tables

Kafka Connect registers one Iceberg sink per source topic. Expected Raw tables include:

- `raw.customer_lead_cdc_connect`
- `raw.customer_lead_icici_cdc_connect`
- `raw.customer_lead_archived_cdc_connect`
- `raw.customer_lead_purge_details_cdc_connect`
- `raw.change_pincode_log_cdc_connect`
- `raw.service_request_assign_log_cdc_connect`
- `raw.service_request_assign_log_archieved_cdc_connect`
- `raw.service_request_assign_log_purge_details_cdc_connect`
- `raw.sr_status_update_log_cdc_connect`
- `raw.sr_status_update_log_archieved_cdc_connect`
- `raw.sr_status_update_log_purge_details_cdc_connect`
- `raw.mas_pincode_cdc_connect`
- `raw.mas_pincode_for_mis_hdfc_cdc_connect`
- `raw.mst_campaign_leads_cdc_connect`

## Initial Bulk Load and CDC Cutover

For large client tables, use bulk initial load plus Debezium CDC cutover.

```text
Enable CDC -> record export LSN/time -> bulk export existing rows
-> load snapshot rows into Raw Iceberg -> start Debezium from cutover point
-> build Silver/Gold -> validate against client totals
```

Why: a full Debezium initial snapshot can be too heavy for large production tables. Bulk export gives better throughput and validation, while CDC covers changes during and after the load.

Proof: source export counts match Raw snapshot counts, CDC changes after cutover land in Raw, and `gold_daily_operations_report` reconciles with client-approved totals.

Fallback: if bulk export is not available, use Debezium initial snapshot during an approved source-load window with sufficient CDC retention.

## Avro and Schema Registry

Kafka Connect uses Confluent Avro converters for keys and values.

Why: Debezium emits strongly typed Kafka Connect schemas. Avro registers a versioned contract per table in Schema Registry, which is closer to a real client UAT/production solution than JSON-only messages.

Proof: `health:source` checks Schema Registry subjects. DSB subjects should appear for topics like `EKYC_ICICI.dbo.Customer_Lead` and `EKYC_ICICI_Archived.dbo.SRStatusUpdateLog_archieved` under the configured Kafka topic prefix.

## Silver Design

Silver recreates the report views in dbt:

- `silver_customer_lead_consolidated`
- `silver_service_request_assign_log_consolidated`
- `silver_sr_status_update_log_consolidated`
- `silver_pincode_serviceability`
- `silver_pincode_state_lookup`
- `silver_campaign_leads`

The lead Silver model uses latest-state interpretation per source row. The log Silver models preserve event/history rows because the Gold report needs to know whether status and assignment events happened.

## Gold Design

Gold model:

- `gold_daily_operations_report`

It applies the report joins, labels, and filters:

- state lookup by current pincode
- agent assignment by order number
- serviceable/non-serviceable pincode flag
- `RPush` versus `Fresh`
- campaign priority flag
- 2-month rolling created/updated date window
- test mobile exclusion

The Gold table lives in StarRocks internal catalog as `default_catalog.analytics.gold_daily_operations_report`.

## Fallback Path

If the Iceberg Kafka Connect sink blocks progress:

```text
Kafka -> Spark Structured Streaming or controlled PyIceberg writer -> Iceberg Raw on MinIO
```

The fallback must preserve the same Raw table contract so dbt Silver/Gold remains unchanged.
