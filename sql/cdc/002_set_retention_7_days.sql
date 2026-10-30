USE mbs_poc;
GO

BEGIN TRY
    EXEC sys.sp_cdc_stop_job @job_type = N'cleanup';
END TRY
BEGIN CATCH
    PRINT N'CDC cleanup job stop skipped: ' + ERROR_MESSAGE();
END CATCH;
GO

EXEC sys.sp_cdc_change_job
    @job_type = N'cleanup',
    @retention = 10080;
GO

BEGIN TRY
    EXEC sys.sp_cdc_start_job @job_type = N'cleanup';
END TRY
BEGIN CATCH
    PRINT N'CDC cleanup job start skipped: ' + ERROR_MESSAGE();
END CATCH;
GO
