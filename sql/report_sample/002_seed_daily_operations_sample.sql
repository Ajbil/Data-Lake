USE EKYC_ICICI;
GO

INSERT INTO dbo.MasPincode (PinCode, State, SCode, District, DCode, IsServiceable, IsMetro)
VALUES
    ('400001', 'Maharashtra', 'MH', 'Mumbai', 'MUM', 1, 1),
    ('560001', 'Karnataka', 'KA', 'Bengaluru', 'BLR', 1, 1),
    ('110001', 'Delhi', 'DL', 'New Delhi', 'DEL', 1, 1),
    ('999999', 'Unknown', 'NA', 'Unknown', 'NA', 0, 0);

INSERT INTO dbo.Mas_Pincode_For_MIS_HDFC (ISeqNo, PinCode, State, SCode, District, DCode, CreatedDate)
VALUES
    (1, '400001', 'Maharashtra', 'MH', 'Mumbai', 'MUM', SYSUTCDATETIME()),
    (2, '560001', 'Karnataka', 'KA', 'Bengaluru', 'BLR', SYSUTCDATETIME()),
    (3, '110001', 'Delhi', 'DL', 'New Delhi', 'DEL', SYSUTCDATETIME()),
    (4, '999999', 'Unknown', 'NA', 'Unknown', 'NA', SYSUTCDATETIME());

INSERT INTO dbo.MBSUser
    (UserID, FirstName, MiddleName, LastName, Active, InsertedDate, Updatedate, UserType, ReportingTo, NVPassword, NVLoginId, BankAllocation, SelectedBanks, AgentType)
VALUES
    ('SUP1', 'Suman', NULL, 'Supervisor', 1, SYSUTCDATETIME(), SYSUTCDATETIME(), 2, NULL, 'sample-only', 'SUP1', 3, 'ICICI', 20),
    ('SUP2', 'Neha', NULL, 'Supervisor', 1, SYSUTCDATETIME(), SYSUTCDATETIME(), 2, NULL, 'sample-only', 'SUP2', 3, 'ICICI', 20),
    ('SUP3', 'Karan', NULL, 'Supervisor', 1, SYSUTCDATETIME(), SYSUTCDATETIME(), 2, NULL, 'sample-only', 'SUP3', 3, 'ICICI', 20),
    ('SUP4', 'Isha', NULL, 'Supervisor', 1, SYSUTCDATETIME(), SYSUTCDATETIME(), 2, NULL, 'sample-only', 'SUP4', 3, 'ICICI', 20),
    ('SUP5', 'Amit', NULL, 'Supervisor', 1, SYSUTCDATETIME(), SYSUTCDATETIME(), 2, NULL, 'sample-only', 'SUP5', 3, 'ICICI', 20),
    ('AG001', 'Ravi', NULL, 'Agent', 1, SYSUTCDATETIME(), SYSUTCDATETIME(), 3, 'SUP1', 'sample-only', 'AG001', 3, 'ICICI', 30),
    ('AG002', 'Priya', NULL, 'Agent', 1, SYSUTCDATETIME(), SYSUTCDATETIME(), 3, 'SUP2', 'sample-only', 'AG002', 3, 'ICICI', 30),
    ('AG003', 'Arjun', NULL, 'Agent', 1, SYSUTCDATETIME(), SYSUTCDATETIME(), 3, 'SUP3', 'sample-only', 'AG003', 3, 'ICICI', 30),
    ('AG004', 'Meera', NULL, 'Agent', 1, SYSUTCDATETIME(), SYSUTCDATETIME(), 3, 'SUP4', 'sample-only', 'AG004', 3, 'ICICI', 30),
    ('AG005', 'Kabir', NULL, 'Agent', 1, SYSUTCDATETIME(), SYSUTCDATETIME(), 3, 'SUP5', 'sample-only', 'AG005', 3, 'ICICI', 30);

INSERT INTO dbo.Customer_Lead
    (ORDER_NUMBER, DESTINATION_CITY, PINCODE, STATE, MOBILE, Bank_Status, DTCreatedDate, DTUpdateDate, SR_Status, ChannelCode, RefNumber, SourceSystem, BankId, ClientName, CustLandMark, ServiceTypeID, Sub_Status)
VALUES
    ('REF-FRESH-HP', 'Mumbai', '400001', 'Maharashtra', '9000000001', 'OPEN', DATEADD(DAY, -2, SYSUTCDATETIME()), SYSUTCDATETIME(), 1, 'DSB', 'REF-FRESH-HP', 'WEB', 3, 'ICICI', 'Near station', 1, 0),
    ('REF-RPUSH-NON', 'Unknown City', '999999', 'Unknown', '9000000002', 'OPEN', DATEADD(DAY, -4, SYSUTCDATETIME()), SYSUTCDATETIME(), 1, 'DSB', 'REF-RPUSH-NON', 'APP', 3, 'ICICI', 'Remote address', 1, 0),
    ('REF-TEST-MOBILE', 'Mumbai', '400001', 'Maharashtra', '8527999655', 'OPEN', DATEADD(DAY, -1, SYSUTCDATETIME()), SYSUTCDATETIME(), 1, 'DSB', 'REF-TEST-MOBILE', 'WEB', 3, 'ICICI', 'Excluded test row', 1, 0);

INSERT INTO dbo.Customer_Lead_ICICI
    (ORDER_NUMBER, DESTINATION_CITY, PINCODE, STATE, MOBILE, Bank_Status, DTCreatedDate, DTUpdateDate, SR_Status, ChannelCode, RefNumber, SourceSystem, BankId, ClientName, CustLandMark, ServiceTypeID, Sub_Status)
VALUES
    ('REF-ICICI-HP', 'Bengaluru', '560001', 'Karnataka', '9000000003', 'OPEN', DATEADD(DAY, -3, SYSUTCDATETIME()), SYSUTCDATETIME(), 1, 'ICICI', 'REF-ICICI-HP', 'CRM', 3, 'ICICI', 'MG Road', 2, 0);

INSERT INTO dbo.ChangePincode_log
    (Refnumber, OldPicode, NewPicode, UpdateBy, UpdateDate, OldAddress, NewAddress)
VALUES
    ('REF-FRESH-HP', '110001', '400001', 'USR1', DATEADD(DAY, -1, SYSUTCDATETIME()), 'Old Delhi Address', 'Mumbai Address');

INSERT INTO dbo.ServiceRequestAssignLog
    (ORDER_NUMBER, UserID, StatusID, UpdateStatusDate, Active, AgentId)
VALUES
    ('REF-FRESH-HP', 'SUP1', 2, SYSUTCDATETIME(), 1, 'AG001'),
    ('REF-RPUSH-NON', 'SUP2', 2, SYSUTCDATETIME(), 1, 'AG002'),
    ('REF-ICICI-HP', 'SUP3', 2, SYSUTCDATETIME(), 1, 'AG003');

INSERT INTO dbo.SRStatusUpdateLog
    (ORDER_NUMBER, UserID, StatusID, LogDate, AgentId, Supervisor, Coordinator, CustomerAvailablePincode, SubStatus)
VALUES
    ('REF-RPUSH-NON', 'USR2', 1, SYSUTCDATETIME(), 'AG002', 'SUP2', 'COORD2', '999999', 0);

INSERT INTO dbo.MstCampaignLeads
    (AgentId, OrderNumber, AppointmentDateTime, DtCreatedDate, DtUpdatedDate, status, Remarks, SpecialCampaign, Price)
VALUES
    ('AG001', 'REF-FRESH-HP', DATEADD(HOUR, 2, SYSUTCDATETIME()), SYSUTCDATETIME(), SYSUTCDATETIME(), 1, 'Priority demo lead', 1, '0'),
    ('AG003', 'REF-ICICI-HP', DATEADD(HOUR, 3, SYSUTCDATETIME()), SYSUTCDATETIME(), SYSUTCDATETIME(), 1, 'Priority ICICI lead', 1, '0');
GO

USE EKYC_ICICI_Archived;
GO

INSERT INTO dbo.Customer_Lead_Archived
    (ORDER_NUMBER, DESTINATION_CITY, PINCODE, STATE, MOBILE, Bank_Status, DTCreatedDate, DTUpdateDate, SR_Status, ChannelCode, RefNumber, SourceSystem, BankId, ClientName, CustLandMark, ServiceTypeID, Sub_Status)
VALUES
    ('REF-ARCH-RPUSH', 'Delhi', '110001', 'Delhi', '9000000004', 'ARCHIVED', DATEADD(DAY, -10, SYSUTCDATETIME()), DATEADD(DAY, -1, SYSUTCDATETIME()), 1, 'DSB', 'REF-ARCH-RPUSH', 'ARCHIVE', 3, 'ICICI', 'CP', 1, 0);

INSERT INTO dbo.Customer_Lead_purge_details
    (CustomerId, ORDER_NUMBER, DESTINATION_CITY, PINCODE, STATE, MOBILE, Bank_Status, DTCreatedDate, DTUpdateDate, SR_Status, ChannelCode, RefNumber, SourceSystem, BankId, ClientName, CustLandMark, ServiceTypeID, Sub_Status)
VALUES
    (9001, 'REF-PURGE-FRESH', 'Mumbai', '400001', 'Maharashtra', '9000000005', 'PURGED', DATEADD(DAY, -20, SYSUTCDATETIME()), SYSUTCDATETIME(), 1, 'DSB', 'REF-PURGE-FRESH', 'PURGE', 3, 'ICICI', 'Purged landmark', 1, 0);

INSERT INTO dbo.ServiceRequestAssignLog_archieved
    (ORDER_NUMBER, UserID, StatusID, UpdateStatusDate, Active, agentid)
VALUES
    ('REF-ARCH-RPUSH', 'SUP4', 2, SYSUTCDATETIME(), 1, 'AG004');

INSERT INTO dbo.ServiceRequestAssignLog_purge_details
    (ORDER_NUMBER, UserID, StatusID, UpdateStatusDate, Active, AgentId, Logdate)
VALUES
    ('REF-PURGE-FRESH', 'SUP5', 2, SYSUTCDATETIME(), 1, 'AG005', SYSUTCDATETIME());

INSERT INTO dbo.SRStatusUpdateLog_archieved
    (ORDER_NUMBER, UserID, StatusID, LogDate, AgentId, Supervisor, Coordinator, CustomerAvailablePincode, SubStatus)
VALUES
    ('REF-ARCH-RPUSH', 'USR4', 1, SYSUTCDATETIME(), 'AG004', 'SUP4', 'COORD4', '110001', 0);

INSERT INTO dbo.SRStatusUpdateLog_purge_details
    (LogId, ORDER_NUMBER, UserID, StatusID, LogDate, AgentId, Supervisor, Coordinator, CustomerAvailablePincode, SubStatus)
VALUES
    (9901, 'REF-PURGE-FRESH', 'USR5', 2, SYSUTCDATETIME(), 'AG005', 'SUP5', 'COORD5', '400001', 0);
GO
