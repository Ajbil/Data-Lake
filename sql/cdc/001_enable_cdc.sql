USE mbs_poc;
GO

IF (SELECT is_cdc_enabled FROM sys.databases WHERE name = N'mbs_poc') = 0
BEGIN
    EXEC sys.sp_cdc_enable_db;
END;
GO

IF NOT EXISTS (SELECT 1 FROM cdc.change_tables WHERE source_object_id = OBJECT_ID(N'dbo.agents'))
BEGIN
    EXEC sys.sp_cdc_enable_table
        @source_schema = N'dbo',
        @source_name = N'agents',
        @role_name = NULL,
        @supports_net_changes = 0;
END;
GO

IF NOT EXISTS (SELECT 1 FROM cdc.change_tables WHERE source_object_id = OBJECT_ID(N'dbo.kyc_completions'))
BEGIN
    EXEC sys.sp_cdc_enable_table
        @source_schema = N'dbo',
        @source_name = N'kyc_completions',
        @role_name = NULL,
        @supports_net_changes = 0;
END;
GO

BEGIN TRY
    EXEC sys.sp_cdc_start_job @job_type = N'capture';
END TRY
BEGIN CATCH
    PRINT N'CDC capture job start skipped: ' + ERROR_MESSAGE();
END CATCH;
GO

BEGIN TRY
    EXEC sys.sp_cdc_start_job @job_type = N'cleanup';
END TRY
BEGIN CATCH
    PRINT N'CDC cleanup job start skipped: ' + ERROR_MESSAGE();
END CATCH;
GO
