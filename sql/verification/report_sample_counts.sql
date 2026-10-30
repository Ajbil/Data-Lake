SELECT 'EKYC_ICICI.Customer_Lead' AS table_name, COUNT(*) AS row_count FROM EKYC_ICICI.dbo.Customer_Lead
UNION ALL SELECT 'EKYC_ICICI.Customer_Lead_ICICI', COUNT(*) FROM EKYC_ICICI.dbo.Customer_Lead_ICICI
UNION ALL SELECT 'EKYC_ICICI.ChangePincode_log', COUNT(*) FROM EKYC_ICICI.dbo.ChangePincode_log
UNION ALL SELECT 'EKYC_ICICI.ServiceRequestAssignLog', COUNT(*) FROM EKYC_ICICI.dbo.ServiceRequestAssignLog
UNION ALL SELECT 'EKYC_ICICI.SRStatusUpdateLog', COUNT(*) FROM EKYC_ICICI.dbo.SRStatusUpdateLog
UNION ALL SELECT 'EKYC_ICICI.MasPincode', COUNT(*) FROM EKYC_ICICI.dbo.MasPincode
UNION ALL SELECT 'EKYC_ICICI.Mas_Pincode_For_MIS_HDFC', COUNT(*) FROM EKYC_ICICI.dbo.Mas_Pincode_For_MIS_HDFC
UNION ALL SELECT 'EKYC_ICICI.MstCampaignLeads', COUNT(*) FROM EKYC_ICICI.dbo.MstCampaignLeads
UNION ALL SELECT 'EKYC_ICICI.MBSUser', COUNT(*) FROM EKYC_ICICI.dbo.MBSUser
UNION ALL SELECT 'EKYC_ICICI_Archived.Customer_Lead_Archived', COUNT(*) FROM EKYC_ICICI_Archived.dbo.Customer_Lead_Archived
UNION ALL SELECT 'EKYC_ICICI_Archived.Customer_Lead_purge_details', COUNT(*) FROM EKYC_ICICI_Archived.dbo.Customer_Lead_purge_details
UNION ALL SELECT 'EKYC_ICICI_Archived.ServiceRequestAssignLog_archieved', COUNT(*) FROM EKYC_ICICI_Archived.dbo.ServiceRequestAssignLog_archieved
UNION ALL SELECT 'EKYC_ICICI_Archived.ServiceRequestAssignLog_purge_details', COUNT(*) FROM EKYC_ICICI_Archived.dbo.ServiceRequestAssignLog_purge_details
UNION ALL SELECT 'EKYC_ICICI_Archived.SRStatusUpdateLog_archieved', COUNT(*) FROM EKYC_ICICI_Archived.dbo.SRStatusUpdateLog_archieved
UNION ALL SELECT 'EKYC_ICICI_Archived.SRStatusUpdateLog_purge_details', COUNT(*) FROM EKYC_ICICI_Archived.dbo.SRStatusUpdateLog_purge_details;
GO

SELECT DB_NAME() AS current_database;
GO
