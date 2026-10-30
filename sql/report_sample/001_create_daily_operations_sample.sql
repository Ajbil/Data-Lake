USE master;
GO

IF DB_ID(N'EKYC_ICICI') IS NULL
BEGIN
    CREATE DATABASE EKYC_ICICI;
END;
GO

IF DB_ID(N'EKYC_ICICI_Archived') IS NULL
BEGIN
    CREATE DATABASE EKYC_ICICI_Archived;
END;
GO

IF SUSER_ID(N'mbs_debezium_user') IS NULL
BEGIN
    CREATE LOGIN mbs_debezium_user
        WITH PASSWORD = N'MbsDebezium@12345',
        CHECK_POLICY = OFF,
        CHECK_EXPIRATION = OFF;
END;
GO

ALTER LOGIN mbs_debezium_user ENABLE;
GO

GRANT VIEW SERVER STATE TO mbs_debezium_user;
GO

USE EKYC_ICICI;
GO

IF (SELECT is_cdc_enabled FROM sys.databases WHERE name = N'EKYC_ICICI') = 0
BEGIN
    EXEC sys.sp_cdc_enable_db;
END;
GO

IF USER_ID(N'mbs_debezium_user') IS NULL
BEGIN
    CREATE USER mbs_debezium_user FOR LOGIN mbs_debezium_user;
END;
GO

ALTER ROLE db_datareader ADD MEMBER mbs_debezium_user;
GRANT VIEW DATABASE STATE TO mbs_debezium_user;
GRANT SELECT ON SCHEMA::cdc TO mbs_debezium_user;
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
    IF EXISTS (SELECT 1 FROM cdc.change_tables WHERE source_object_id = OBJECT_ID(N'dbo.' + @table))
    BEGIN
        EXEC sys.sp_cdc_disable_table @source_schema = N'dbo', @source_name = @table, @capture_instance = N'all';
    END;
    FETCH NEXT FROM table_cursor INTO @table;
END;
CLOSE table_cursor;
DEALLOCATE table_cursor;
GO

DROP TABLE IF EXISTS dbo.MstCampaignLeads;
DROP TABLE IF EXISTS dbo.Mas_Pincode_For_MIS_HDFC;
DROP TABLE IF EXISTS dbo.MasPincode;
DROP TABLE IF EXISTS dbo.MBSUser;
DROP TABLE IF EXISTS dbo.SRStatusUpdateLog;
DROP TABLE IF EXISTS dbo.ServiceRequestAssignLog;
DROP TABLE IF EXISTS dbo.ChangePincode_log;
DROP TABLE IF EXISTS dbo.Customer_Lead_ICICI;
DROP TABLE IF EXISTS dbo.Customer_Lead;
GO

CREATE TABLE dbo.Customer_Lead
(
    CustomerId BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Customer_Lead PRIMARY KEY,
    ORDER_NUMBER VARCHAR(100) NULL,
    DESTINATION_CITY VARCHAR(100) NULL,
    PINCODE VARCHAR(50) NULL,
    STATE VARCHAR(100) NULL,
    MOBILE VARCHAR(50) NULL,
    Bank_Status VARCHAR(100) NULL,
    DTCreatedDate DATETIME NULL,
    DTUpdateDate DATETIME NULL,
    SR_Status INT NOT NULL CONSTRAINT DF_CustomerLead_SR_Status DEFAULT (1),
    ChannelCode VARCHAR(100) NULL,
    RefNumber VARCHAR(100) NULL,
    SourceSystem VARCHAR(50) NULL,
    BankId INT NULL CONSTRAINT DF_Customer_Lead_BankId DEFAULT (3),
    ClientName VARCHAR(50) NULL,
    CustLandMark VARCHAR(500) NULL,
    ServiceTypeID INT NULL,
    Sub_Status INT NULL CONSTRAINT DF_Customer_Lead_Sub_Status DEFAULT (0)
);
GO

CREATE TABLE dbo.Customer_Lead_ICICI
(
    CustomerId BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Customer_Lead_ICICI PRIMARY KEY,
    ORDER_NUMBER VARCHAR(100) NULL,
    DESTINATION_CITY VARCHAR(100) NULL,
    PINCODE VARCHAR(50) NULL,
    STATE VARCHAR(100) NULL,
    MOBILE VARCHAR(50) NULL,
    Bank_Status VARCHAR(100) NULL,
    DTCreatedDate DATETIME NULL,
    DTUpdateDate DATETIME NULL,
    SR_Status INT NOT NULL CONSTRAINT DF_CustomerLead_SR_Status_ICICI DEFAULT (1),
    ChannelCode VARCHAR(100) NULL,
    RefNumber VARCHAR(100) NULL,
    SourceSystem VARCHAR(50) NULL,
    BankId INT NULL CONSTRAINT DF_Customer_Lead_BankId_ICICI DEFAULT (3),
    ClientName VARCHAR(50) NULL,
    CustLandMark VARCHAR(500) NULL,
    ServiceTypeID INT NULL,
    Sub_Status INT NULL CONSTRAINT DF_Customer_Lead_ICICI_Sub_Status DEFAULT (0)
);
GO

CREATE TABLE dbo.ChangePincode_log
(
    Id BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ChangePincode_log PRIMARY KEY,
    Refnumber VARCHAR(100) NULL,
    OldPicode VARCHAR(6) NULL,
    NewPicode VARCHAR(6) NULL,
    UpdateBy VARCHAR(12) NULL,
    UpdateDate DATETIME NULL,
    OldAddress VARCHAR(300) NULL,
    OldLandmark VARCHAR(200) NULL,
    OldDistrict VARCHAR(200) NULL,
    OldState VARCHAR(300) NULL,
    NewAddress VARCHAR(300) NULL,
    NewLandmark VARCHAR(200) NULL,
    NewDistrict VARCHAR(200) NULL,
    NewState VARCHAR(300) NULL,
    NewLattitude VARCHAR(20) NULL,
    NewLongitude VARCHAR(20) NULL
);
GO

CREATE TABLE dbo.ServiceRequestAssignLog
(
    ORDER_NUMBER VARCHAR(100) NULL,
    UserID VARCHAR(20) NOT NULL,
    StatusID INT NOT NULL,
    UpdateStatusDate DATETIME NULL CONSTRAINT DF_ServiceRequestAssignLog_UpdateStatusDate DEFAULT (GETDATE()),
    Active BIT NOT NULL CONSTRAINT DF_ServiceRequestAssignLog_Active DEFAULT (1),
    AgentId NVARCHAR(20) NULL
);
GO

CREATE TABLE dbo.SRStatusUpdateLog
(
    LogId BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_SRStatusUpdateLog PRIMARY KEY,
    ORDER_NUMBER VARCHAR(100) NULL,
    UserID VARCHAR(20) NOT NULL,
    StatusID INT NOT NULL,
    UserLatitude VARCHAR(12) NULL,
    UserLongitude VARCHAR(12) NULL,
    Remarks NVARCHAR(2000) NULL,
    LogDate DATETIME NULL CONSTRAINT DF_SRStatusUpdateLog_LogDate DEFAULT (GETDATE()),
    FileName VARCHAR(100) NULL,
    FileContent VARBINARY(MAX) NULL,
    FileContentType VARCHAR(10) NULL,
    RejectionReason NVARCHAR(2000) NULL,
    AgentId VARCHAR(20) NULL,
    Supervisor VARCHAR(100) NULL,
    Coordinator VARCHAR(100) NULL,
    CustomerAvailablePincode VARCHAR(10) NULL,
    SubStatus INT NULL CONSTRAINT DF_SRStatusUpdateLog_SubStatus DEFAULT (0)
);
GO

CREATE TABLE dbo.MasPincode
(
    ISeqNo INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_MasPincode PRIMARY KEY,
    PinCode VARCHAR(50) NULL,
    State VARCHAR(50) NULL,
    SCode VARCHAR(50) NULL,
    District VARCHAR(50) NULL,
    DCode VARCHAR(50) NULL,
    CreatedDate DATETIME NULL CONSTRAINT DF_MasPincode_CreatedDate DEFAULT (GETDATE()),
    IsServiceable INT NULL,
    IsMetro INT NULL
);
GO

CREATE TABLE dbo.Mas_Pincode_For_MIS_HDFC
(
    ISeqNo INT NOT NULL CONSTRAINT PK_Mas_Pincode_For_MIS_HDFC PRIMARY KEY,
    PinCode VARCHAR(50) NULL,
    State VARCHAR(50) NULL,
    SCode VARCHAR(50) NULL,
    District VARCHAR(50) NULL,
    DCode VARCHAR(50) NULL,
    CreatedDate DATETIME NULL
);
GO

CREATE TABLE dbo.MstCampaignLeads
(
    Id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_MstCampaignLeads PRIMARY KEY,
    AgentId VARCHAR(50) NULL,
    OrderNumber NVARCHAR(100) NULL CONSTRAINT UQ_MstCampaignLeads_OrderNumber UNIQUE,
    AppointmentDateTime DATETIME NULL,
    DtCreatedDate DATETIME NULL CONSTRAINT DF_MstCampaignLeads_DtCreatedDate DEFAULT (GETDATE()),
    DtUpdatedDate DATETIME NULL,
    status INT NULL CONSTRAINT DF_MstCampaignLeads_status DEFAULT (0),
    Remarks NVARCHAR(250) NULL,
    SpecialCampaign INT NULL,
    Price VARCHAR(100) NULL
);
GO

CREATE TABLE dbo.MBSUser
(
    ID BIGINT IDENTITY(1,1) NOT NULL,
    UserID NVARCHAR(20) NOT NULL CONSTRAINT PK_MBSUser PRIMARY KEY,
    FirstName VARCHAR(100) NULL,
    MiddleName VARCHAR(100) NULL,
    LastName VARCHAR(100) NULL,
    BusinessAddress NVARCHAR(1000) NULL,
    BusinessLandmark VARCHAR(150) NULL,
    StateId NVARCHAR(20) NULL,
    DistrictId NVARCHAR(20) NULL,
    BusinessCity VARCHAR(50) NULL,
    BusinessPincode INT NULL,
    Active BIT NULL CONSTRAINT DF_MBSUser_Active DEFAULT (1),
    InsertedDate DATETIME NULL CONSTRAINT DF_MBSUser_DTInsertedDate DEFAULT (GETDATE()),
    CreatedBy NVARCHAR(20) NULL,
    Updatedate DATETIME NULL,
    UpdatedBy NVARCHAR(20) NULL,
    UserType TINYINT NULL,
    ReportingTo NVARCHAR(20) NULL,
    NVPassword NVARCHAR(20) NOT NULL CONSTRAINT DF_MBSUser_NVPassword DEFAULT ('sample-only'),
    NoOfTimeLogin INT NULL,
    NVLoginId NVARCHAR(20) NULL,
    BanID VARCHAR(25) NULL,
    LeadEfficiancy VARCHAR(MAX) NULL,
    BankAllocation INT NULL,
    SelectedBanks VARCHAR(200) NULL,
    AgentPhoto VARCHAR(500) NULL,
    DeviceIP VARCHAR(150) NULL,
    TobeCalledEfficency VARCHAR(5) NULL,
    IsSelfieEnable BIT NOT NULL CONSTRAINT DF_MBSUser_IsSelfieEnable DEFAULT (1),
    IsAutoRead BIT NOT NULL CONSTRAINT DF_MBSUser_IsAutoReadEnable DEFAULT (1),
    AgentType INT NULL,
    AgentReason NVARCHAR(MAX) NULL
);
GO

USE EKYC_ICICI_Archived;
GO

IF (SELECT is_cdc_enabled FROM sys.databases WHERE name = N'EKYC_ICICI_Archived') = 0
BEGIN
    EXEC sys.sp_cdc_enable_db;
END;
GO

IF USER_ID(N'mbs_debezium_user') IS NULL
BEGIN
    CREATE USER mbs_debezium_user FOR LOGIN mbs_debezium_user;
END;
GO

ALTER ROLE db_datareader ADD MEMBER mbs_debezium_user;
GRANT VIEW DATABASE STATE TO mbs_debezium_user;
GRANT SELECT ON SCHEMA::cdc TO mbs_debezium_user;
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
    IF EXISTS (SELECT 1 FROM cdc.change_tables WHERE source_object_id = OBJECT_ID(N'dbo.' + @table))
    BEGIN
        EXEC sys.sp_cdc_disable_table @source_schema = N'dbo', @source_name = @table, @capture_instance = N'all';
    END;
    FETCH NEXT FROM table_cursor INTO @table;
END;
CLOSE table_cursor;
DEALLOCATE table_cursor;
GO

DROP TABLE IF EXISTS dbo.SRStatusUpdateLog_purge_details;
DROP TABLE IF EXISTS dbo.SRStatusUpdateLog_archieved;
DROP TABLE IF EXISTS dbo.ServiceRequestAssignLog_purge_details;
DROP TABLE IF EXISTS dbo.ServiceRequestAssignLog_archieved;
DROP TABLE IF EXISTS dbo.Customer_Lead_purge_details;
DROP TABLE IF EXISTS dbo.Customer_Lead_Archived;
GO

CREATE TABLE dbo.Customer_Lead_Archived
(
    CustomerId BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Customer_Lead_Archived PRIMARY KEY,
    ORDER_NUMBER VARCHAR(100) NULL,
    DESTINATION_CITY VARCHAR(100) NULL,
    PINCODE VARCHAR(50) NULL,
    STATE VARCHAR(100) NULL,
    MOBILE VARCHAR(50) NULL,
    Bank_Status VARCHAR(100) NULL,
    DTCreatedDate DATETIME NULL,
    DTUpdateDate DATETIME NULL,
    SR_Status INT NOT NULL CONSTRAINT DF_Customer_Lead_Archived_SR_Status DEFAULT (1),
    ChannelCode VARCHAR(100) NULL,
    RefNumber VARCHAR(100) NULL,
    SourceSystem VARCHAR(50) NULL,
    BankId INT NULL CONSTRAINT DF_Customer_Lead_Archived_BankId DEFAULT (3),
    ClientName VARCHAR(50) NULL,
    CustLandMark VARCHAR(500) NULL,
    ServiceTypeID INT NULL,
    Sub_Status INT NULL CONSTRAINT DF_Customer_Lead_Archived_Sub_Status DEFAULT (0)
);
GO

CREATE TABLE dbo.Customer_Lead_purge_details
(
    CustomerId BIGINT NOT NULL CONSTRAINT PK_Customer_Lead_purge_details PRIMARY KEY,
    ORDER_NUMBER VARCHAR(100) NULL,
    DESTINATION_CITY VARCHAR(100) NULL,
    PINCODE VARCHAR(50) NULL,
    STATE VARCHAR(100) NULL,
    MOBILE VARCHAR(50) NULL,
    Bank_Status VARCHAR(100) NULL,
    DTCreatedDate DATETIME NULL,
    DTUpdateDate DATETIME NULL,
    SR_Status INT NOT NULL,
    ChannelCode VARCHAR(100) NULL,
    RefNumber VARCHAR(100) NULL,
    SourceSystem VARCHAR(50) NULL,
    BankId INT NULL,
    ClientName VARCHAR(50) NULL,
    CustLandMark VARCHAR(500) NULL,
    ServiceTypeID INT NULL,
    Sub_Status INT NULL
);
GO

CREATE TABLE dbo.ServiceRequestAssignLog_archieved
(
    ORDER_NUMBER VARCHAR(100) NOT NULL,
    UserID VARCHAR(20) NOT NULL,
    StatusID INT NOT NULL,
    UpdateStatusDate DATETIME NULL,
    Active BIT NOT NULL,
    agentid NVARCHAR(80) NULL,
    Id BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ServiceRequestAssignLog_archieved PRIMARY KEY
);
GO

CREATE TABLE dbo.ServiceRequestAssignLog_purge_details
(
    ORDER_NUMBER VARCHAR(100) NOT NULL,
    UserID VARCHAR(20) NOT NULL,
    StatusID INT NOT NULL,
    UpdateStatusDate DATETIME NULL,
    Active BIT NOT NULL,
    AgentId NVARCHAR(40) NULL,
    Logdate DATETIME NOT NULL,
    Id BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ServiceRequestAssignLog_purge_details PRIMARY KEY
);
GO

CREATE TABLE dbo.SRStatusUpdateLog_archieved
(
    LogId BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_SRStatusUpdateLog_archieved PRIMARY KEY,
    ORDER_NUMBER VARCHAR(100) NULL,
    UserID VARCHAR(20) NOT NULL,
    StatusID INT NOT NULL,
    UserLatitude VARCHAR(12) NULL,
    UserLongitude VARCHAR(12) NULL,
    Remarks NVARCHAR(2000) NULL,
    LogDate DATETIME NULL,
    FileName VARCHAR(100) NULL,
    FileContent VARBINARY(MAX) NULL,
    FileContentType VARCHAR(10) NULL,
    RejectionReason NVARCHAR(2000) NULL,
    AgentId VARCHAR(20) NULL,
    Supervisor VARCHAR(100) NULL,
    Coordinator VARCHAR(100) NULL,
    CustomerAvailablePincode VARCHAR(10) NULL,
    SubStatus INT NULL
);
GO

CREATE TABLE dbo.SRStatusUpdateLog_purge_details
(
    LogId BIGINT NOT NULL CONSTRAINT PK_SRStatusUpdateLog_purge_details PRIMARY KEY,
    ORDER_NUMBER VARCHAR(100) NOT NULL,
    UserID VARCHAR(20) NOT NULL,
    StatusID INT NOT NULL,
    UserLatitude VARCHAR(12) NULL,
    UserLongitude VARCHAR(12) NULL,
    Remarks VARCHAR(2000) NULL,
    LogDate DATETIME NULL,
    FileName VARCHAR(100) NULL,
    FileContent VARBINARY(MAX) NULL,
    FileContentType VARCHAR(10) NULL,
    RejectionReason NVARCHAR(2000) NULL,
    AgentId VARCHAR(20) NULL,
    Supervisor VARCHAR(100) NULL,
    Coordinator VARCHAR(100) NULL,
    CustomerAvailablePincode VARCHAR(10) NULL,
    deletedate DATETIME NULL,
    SubStatus INT NULL
);
GO
