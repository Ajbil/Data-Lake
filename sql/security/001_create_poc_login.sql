USE master;
GO

IF SUSER_ID(N'mbs_poc_user') IS NULL
BEGIN
    CREATE LOGIN mbs_poc_user
        WITH PASSWORD = N'MbsPoc@12345',
        CHECK_POLICY = OFF,
        CHECK_EXPIRATION = OFF;
END;
GO

ALTER LOGIN mbs_poc_user ENABLE;
GO

USE mbs_poc;
GO

IF USER_ID(N'mbs_poc_user') IS NULL
BEGIN
    CREATE USER mbs_poc_user FOR LOGIN mbs_poc_user;
END;
GO

ALTER ROLE db_owner ADD MEMBER mbs_poc_user;
GO
