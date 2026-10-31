INSERT INTO quality_step4_742501b1.silver_customer_lead_consolidated (source_table,customer_id,ref_number,order_number,dt_created_date,is_active_arn)
VALUES ('Customer_Lead',999999999,'QUALITY-STEP4-VALID','QUALITY-STEP4-VALID',current_date(),1);
INSERT INTO quality_step4_742501b1.gold_daily_operations_report (order_number,lead_source_table,serviceable_pincode,record_type,champaines,is_active_arn,agent_id)
VALUES ('QUALITY-STEP4-ORPHAN','Customer_Lead',NULL,NULL,NULL,1,'QUALITY-STEP4-MISSING-USER');
