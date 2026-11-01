# Daily Operations Report Schema Contracts

## Purpose

Define the operational report contracts reproduced by the local synthetic POC.
The database/table names retain their original report-domain names; this personal
demo captures physical tables in `EKYC_ICICI` and `EKYC_ICICI_Archived`, not the
original `EKYC_ICICI_Report` view results. See the [current flow](01_end_to_end_flow.md).

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
| `dbo.MBSUser` | Agent and supervisor lookup. |

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
| `silver_change_pincode_log` | Keyed pincode-change history used to recover the original pincode |
| `silver_mbs_user` | Current agent/user master and supervisor relationships |

There are fifteen physical report sources and eight Silver models. Silver lead
grain is `(source_table, customer_id)`. Gold is a native StarRocks table preserving
eligible Silver rows, not an assertion that each order number is globally unique.
Its date window starts at month start two months before the current date (created
OR updated), so dated fixture counts can change over time.

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

## Keyed CDC Current State

Silver reads each keyed physical source through `current_cdc_rows`. It resolves
the key from `after` or a delete's `before`, ranks `r/c/u/d` together, then removes
a latest delete. Ordering uses SQL Server commit LSN, initial-snapshot precedence
at an equal boundary, change LSN and event serial number; source/arrival timestamps
are fallbacks. This assumes canonical fixed-width SQL Server LSNs and immutable
events within one source per Raw table. Database restore/LSN reset and conflicting
payloads at identical coordinates require a separate recovery policy.

This preserves separate log IDs as history rows while removing superseded CDC
versions. It does not deduplicate business leads across active/archive tables.
The active `ServiceRequestAssignLog` has no stable key and retains its existing
history path; deletes/updates for that keyless source are outside this guarantee.
Its archived and purge tables have `Id` and use keyed current state.

Proof: the `cdc_current_rows` dbt test runs synthetic structs on StarRocks,
including deletes, source-order/clock disagreement, equal timestamps, snapshots,
replay and key reuse. A live tagged source-to-Gold check is documented in the
[execution runbook](../runbooks/02_poc_execution.md#basic-keyed-cdc-correctness-check).
If the source contract is unavailable, keep Raw intact and investigate rather
than resetting offsets or claiming a reliable current state.

## PII and Decryption Caveat

The supplied SQL Server views call `dbo.DecryptedData()` for encrypted base-table fields. Raw CDC from the physical base tables will carry the stored base-table values, not automatically the decrypted view output.

This is a required client decision before production hardening:

- provide approved source-side decrypted/report-safe staging columns, or
- provide the decryption logic for downstream use, or
- mask/exclude encrypted PII fields in the lakehouse.

For the current POC implementation, the view logic is represented in dbt and the decryption dependency is documented as a known source contract dependency.
