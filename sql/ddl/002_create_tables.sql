USE mbs_poc;
GO

IF OBJECT_ID(N'cdc.change_tables', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM cdc.change_tables WHERE source_object_id = OBJECT_ID(N'dbo.kyc_completions'))
BEGIN
    EXEC sys.sp_cdc_disable_table
        @source_schema = N'dbo',
        @source_name = N'kyc_completions',
        @capture_instance = N'all';
END;
GO

IF OBJECT_ID(N'cdc.change_tables', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM cdc.change_tables WHERE source_object_id = OBJECT_ID(N'dbo.agents'))
BEGIN
    EXEC sys.sp_cdc_disable_table
        @source_schema = N'dbo',
        @source_name = N'agents',
        @capture_instance = N'all';
END;
GO

IF OBJECT_ID(N'dbo.kyc_completions', N'U') IS NOT NULL
BEGIN
    DROP TABLE dbo.kyc_completions;
END;
GO

IF OBJECT_ID(N'dbo.agents', N'U') IS NOT NULL
BEGIN
    DROP TABLE dbo.agents;
END;
GO

CREATE TABLE dbo.agents
(
    agent_id INT IDENTITY(1,1) NOT NULL CONSTRAINT pk_agents PRIMARY KEY,
    agent_code NVARCHAR(30) NOT NULL CONSTRAINT uq_agents_agent_code UNIQUE,
    agent_name NVARCHAR(120) NOT NULL,
    bank_code NVARCHAR(20) NOT NULL,
    state_code NVARCHAR(10) NOT NULL,
    city NVARCHAR(80) NOT NULL,
    status NVARCHAR(20) NOT NULL CONSTRAINT df_agents_status DEFAULT N'ACTIVE',
    created_at DATETIME2(3) NOT NULL CONSTRAINT df_agents_created_at DEFAULT SYSUTCDATETIME(),
    updated_at DATETIME2(3) NOT NULL CONSTRAINT df_agents_updated_at DEFAULT SYSUTCDATETIME()
);
GO

CREATE TABLE dbo.kyc_completions
(
    kyc_completion_id INT IDENTITY(1,1) NOT NULL CONSTRAINT pk_kyc_completions PRIMARY KEY,
    agent_id INT NOT NULL,
    customer_reference NVARCHAR(80) NOT NULL,
    kyc_status NVARCHAR(20) NOT NULL,
    completion_channel NVARCHAR(20) NOT NULL,
    completed_at DATETIME2(3) NULL,
    created_at DATETIME2(3) NOT NULL CONSTRAINT df_kyc_completions_created_at DEFAULT SYSUTCDATETIME(),
    updated_at DATETIME2(3) NOT NULL CONSTRAINT df_kyc_completions_updated_at DEFAULT SYSUTCDATETIME(),
    event_tag NVARCHAR(80) NULL,
    CONSTRAINT fk_kyc_completions_agents FOREIGN KEY (agent_id) REFERENCES dbo.agents(agent_id)
);
GO
