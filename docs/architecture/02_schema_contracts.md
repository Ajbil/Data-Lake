# Daily Operations Report Schema Contracts

## Purpose

Define the client report source contracts now used by the POC. The report is the DSB-SahiBnk Daily Operations Report over SQL Server `EKYC_ICICI`, `EKYC_ICICI_Archived`, and reporting views from `EKYC_ICICI_Report`.

## Source Tables Captured by CDC

Current database: `EKYC_ICICI`.

| Table | Purpose in report |
| --- | --- |
| `dbo.Customer_Lead` | Active customer leads. |
| `dbo.Customer_Lead_ICICI` | ICICI customer leads included in the consolidated lead view. |
| `dbo.ChangePincode_log` | First/original pincode lookup for a lead. |
| `dbo.ServiceRequestAssignLog` | Active service request assignment events. |
| `dbo.SRStatusUpdateLog` | Active status update events used for `RPush`/`Fresh`. |
| `dbo.MasPincode` | Serviceability lookup. |
| `dbo.Mas_Pincode_For_MIS_HDFC` | Pincode-to-state lookup. |
| `dbo.MstCampaignLeads` | Campaign/appointment source for priority tagging. |

Archived database: `EKYC_ICICI_Archived`.

| Table | Purpose in report |
| --- | --- |
| `dbo.Customer_Lead_Archived` | Archived customer leads. |
| `dbo.Customer_Lead_purge_details` | Purged customer leads. |
| `dbo.ServiceRequestAssignLog_archieved` | Archived assignment events. |
| `dbo.ServiceRequestAssignLog_purge_details` | Purged assignment events. |
| `dbo.SRStatusUpdateLog_archieved` | Archived status update events. Client confirmed it matches `SRStatusUpdateLog` structure. |
| `dbo.SRStatusUpdateLog_purge_details` | Purged status update events. |

Why: these are the physical tables behind the report views. Debezium captures SQL Server tables, not view result sets.

Previous technology: SQL Server source writes, retention movement, and reporting views.

Next technology: Debezium captures these tables into Kafka Avro topics and Kafka Connect writes them to Raw Iceberg tables.

## Silver Contracts

Silver recreates the client view logic in dbt:

| Model | Replaces/recreates |
| --- | --- |
| `silver_customer_lead_consolidated` | `View_Customer_Lead_consolidated` |
| `silver_service_request_assign_log_consolidated` | `View_ServiceRequestAssignLog_consolidated` |
| `silver_sr_status_update_log_consolidated` | `View_SRStatusUpdateLog_consolidated` |
| `silver_pincode_serviceability` | Distinct serviceable pincode lookup from `MasPincode` |
| `silver_pincode_state_lookup` | State lookup from `Mas_Pincode_For_MIS_HDFC` |
| `silver_campaign_leads` | `VIEW_MstCampaignLeads` readable campaign/appointment fields |

## Gold Contract

Gold model:

- `gold_daily_operations_report`

It exposes the report fields used by PowerBI:

- `order_number`
- `destination_city`
- `bank_status`
- `base_pincode`
- `pincode`
- `state`
- `dt_created_date`
- `dt_update_date`
- `sr_status`
- `channel_code`
- `source_system`
- `bank_id`
- `client_name`
- `cust_landmark`
- `agent_id`
- `serviceable_pincode`
- `record_type`
- `champaines`
- `appointment_date_time`
- `appointment_created_date`
- `is_active_arn`

## PII and Decryption Caveat

The supplied SQL Server views call `dbo.DecryptedData()` for encrypted base-table fields. Raw CDC from the physical base tables will carry the stored base-table values, not automatically the decrypted view output.

This is a required client decision before production hardening:

- provide approved source-side decrypted/report-safe staging columns, or
- provide the decryption logic for downstream use, or
- mask/exclude encrypted PII fields in the lakehouse.

For the current POC implementation, the view logic is represented in dbt and the decryption dependency is documented as a known source contract dependency.
