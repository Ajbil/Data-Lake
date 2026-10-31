INSERT INTO quality_step4_742501b1.silver_customer_lead_consolidated (source_table,customer_id,ref_number,order_number,dt_created_date,is_active_arn)
VALUES ('Customer_Lead',999999999,'QUALITY-STEP4-VALID','QUALITY-STEP4-VALID',current_date(),1),
       ('Customer_Lead_Archived',999999999,'QUALITY-STEP4-VALID','QUALITY-STEP4-VALID',current_date(),0);
INSERT INTO quality_step4_742501b1.gold_daily_operations_report (order_number,lead_source_table,serviceable_pincode,record_type,champaines,is_active_arn,agent_id)
VALUES ('QUALITY-STEP4-VALID','Customer_Lead','Serviceable','Fresh','Non-priority',1,NULL),
       ('QUALITY-STEP4-VALID','Customer_Lead_Archived','Non-Serviceable','Fresh','Non-priority',0,NULL);
