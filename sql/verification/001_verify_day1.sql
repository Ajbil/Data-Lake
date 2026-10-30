USE mbs_poc;
GO

SELECT
    name AS database_name,
    is_cdc_enabled
FROM sys.databases
WHERE name = N'mbs_poc';
GO

SELECT
    s.name AS schema_name,
    t.name AS table_name,
    t.is_tracked_by_cdc
FROM sys.tables t
JOIN sys.schemas s ON s.schema_id = t.schema_id
WHERE s.name = N'dbo'
  AND t.name IN (N'agents', N'kyc_completions')
ORDER BY t.name;
GO

SELECT
    job_type,
    retention,
    pollinginterval,
    maxtrans,
    maxscans
FROM msdb.dbo.cdc_jobs
WHERE database_id = DB_ID(N'mbs_poc');
GO

SELECT COUNT(*) AS agent_count FROM dbo.agents;
GO

SELECT bank_code, COUNT(*) AS agent_count
FROM dbo.agents
GROUP BY bank_code
ORDER BY bank_code;
GO

SELECT COUNT(*) AS kyc_completion_count FROM dbo.kyc_completions;
GO

INSERT INTO dbo.kyc_completions
    (agent_id, customer_reference, kyc_status, completion_channel, completed_at, event_tag)
VALUES
    (1, N'CUST-POC-DAY1-VERIFY', N'COMPLETED', N'DIGITAL', SYSUTCDATETIME(), N'day1-cdc-verification');
GO

WAITFOR DELAY '00:00:05';
GO

DECLARE @from_lsn BINARY(10) = sys.fn_cdc_get_min_lsn('dbo_kyc_completions');
DECLARE @to_lsn BINARY(10) = sys.fn_cdc_get_max_lsn();

SELECT TOP (10)
    __$operation,
    kyc_completion_id,
    agent_id,
    customer_reference,
    kyc_status,
    event_tag
FROM cdc.fn_cdc_get_all_changes_dbo_kyc_completions(@from_lsn, @to_lsn, 'all')
WHERE event_tag = N'day1-cdc-verification'
ORDER BY __$start_lsn DESC;
GO
