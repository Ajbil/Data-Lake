USE master;
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

USE mbs_poc;
GO

IF USER_ID(N'mbs_debezium_user') IS NULL
BEGIN
    CREATE USER mbs_debezium_user FOR LOGIN mbs_debezium_user;
END;
GO

ALTER ROLE db_datareader ADD MEMBER mbs_debezium_user;
GO

GRANT VIEW DATABASE STATE TO mbs_debezium_user;
GO

GRANT SELECT ON SCHEMA::cdc TO mbs_debezium_user;
GO
