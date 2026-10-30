USE EKYC_ICICI;
GO

DECLARE @tables TABLE (name sysname);
INSERT INTO @tables (name)
VALUES
    (N'Customer_Lead'),
    (N'Customer_Lead_ICICI'),
    (N'ChangePincode_log'),
    (N'ServiceRequestAssignLog'),
    (N'SRStatusUpdateLog'),
    (N'MasPincode'),
    (N'Mas_Pincode_For_MIS_HDFC'),
    (N'MstCampaignLeads'),
    (N'MBSUser');

DECLARE @table sysname;
DECLARE table_cursor CURSOR LOCAL FAST_FORWARD FOR SELECT name FROM @tables;
OPEN table_cursor;
FETCH NEXT FROM table_cursor INTO @table;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF NOT EXISTS (SELECT 1 FROM cdc.change_tables WHERE source_object_id = OBJECT_ID(N'dbo.' + @table))
    BEGIN
        EXEC sys.sp_cdc_enable_table
            @source_schema = N'dbo',
            @source_name = @table,
            @role_name = NULL,
            @supports_net_changes = 0;
    END;
    FETCH NEXT FROM table_cursor INTO @table;
END;
CLOSE table_cursor;
DEALLOCATE table_cursor;
GO

USE EKYC_ICICI_Archived;
GO

DECLARE @tables TABLE (name sysname);
INSERT INTO @tables (name)
VALUES
    (N'Customer_Lead_Archived'),
    (N'Customer_Lead_purge_details'),
    (N'ServiceRequestAssignLog_archieved'),
    (N'ServiceRequestAssignLog_purge_details'),
    (N'SRStatusUpdateLog_archieved'),
    (N'SRStatusUpdateLog_purge_details');

DECLARE @table sysname;
DECLARE table_cursor CURSOR LOCAL FAST_FORWARD FOR SELECT name FROM @tables;
OPEN table_cursor;
FETCH NEXT FROM table_cursor INTO @table;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF NOT EXISTS (SELECT 1 FROM cdc.change_tables WHERE source_object_id = OBJECT_ID(N'dbo.' + @table))
    BEGIN
        EXEC sys.sp_cdc_enable_table
            @source_schema = N'dbo',
            @source_name = @table,
            @role_name = NULL,
            @supports_net_changes = 0;
    END;
    FETCH NEXT FROM table_cursor INTO @table;
END;
CLOSE table_cursor;
DEALLOCATE table_cursor;
GO

PRINT N'CDC table registration complete. Capture and cleanup jobs may already be running in the local SQL Server Agent.';
GO
