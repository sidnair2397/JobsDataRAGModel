/*
This file contains the SQL code for creating triggers in the database. 
*/

-- 1.1 Job Fact Audit
CREATE OR ALTER TRIGGER trg_Job_Audit
ON Job_Fact_Table
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @TableName NVARCHAR(255) = 'Job_Fact_Table';
    DECLARE @User NVARCHAR(255) = SYSTEM_USER;

    -- INSERT
    INSERT INTO Audit_Log_Table (table_name, operation, record_id, changed_by, details)
    SELECT @TableName, 'INSERT', i.job_id, @User, 
           CONCAT('New Job Created: ', LEFT(i.job_title, 50))
    FROM inserted i
    LEFT JOIN deleted d ON i.job_id = d.job_id WHERE d.job_id IS NULL;

    -- UPDATE
    INSERT INTO Audit_Log_Table (table_name, operation, record_id, changed_by, details)
    SELECT @TableName, 'UPDATE', i.job_id, @User, 
           CONCAT('Job Updated. Status: ', i.work_type)
    FROM inserted i
    INNER JOIN deleted d ON i.job_id = d.job_id;

    -- DELETE
    INSERT INTO Audit_Log_Table (table_name, operation, record_id, changed_by, details)
    SELECT @TableName, 'DELETE', d.job_id, @User, 
           CONCAT('Job Deleted: ', LEFT(d.job_title, 50))
    FROM deleted d
    LEFT JOIN inserted i ON d.job_id = i.job_id WHERE i.job_id IS NULL;
END;
GO

-- 1.2 Company Dimension Audit
CREATE OR ALTER TRIGGER trg_Company_Audit
ON Company_Dimension_Table
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @TableName NVARCHAR(255) = 'Company_Dimension_Table';

    INSERT INTO Audit_Log_Table (table_name, operation, record_id, changed_by, details)
    SELECT @TableName, 'INSERT', i.company_id, SYSTEM_USER, CONCAT('Company Added: ',i.company_name)
    FROM inserted i LEFT JOIN deleted d ON i.company_id = d.company_id WHERE d.company_id IS NULL;

    INSERT INTO Audit_Log_Table (table_name, operation, record_id, changed_by, details)
    SELECT @TableName, 'UPDATE', i.company_id, SYSTEM_USER, CONCAT('Company Updated: ', i.company_name)
    FROM inserted i INNER JOIN deleted d ON i.company_id = d.company_id;

    INSERT INTO Audit_Log_Table (table_name, operation, record_id, changed_by, details)
    SELECT @TableName, 'DELETE', d.company_id, SYSTEM_USER, CONCAT('Company Deleted: ', d.company_name)
    FROM deleted d LEFT JOIN inserted i ON d.company_id = i.company_id WHERE i.company_id IS NULL;
END;
GO

-- 1.3 Location Dimension Audit
CREATE OR ALTER TRIGGER trg_Location_Audit
ON Location_Dimension_Table
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @TableName NVARCHAR(255) = 'Location_Dimension_Table';

    INSERT INTO Audit_Log_Table (table_name, operation, record_id, changed_by, details)
    SELECT @TableName, 'INSERT', i.location_id, SYSTEM_USER, CONCAT('Location Added: ', i.city, ', ', i.country)
    FROM inserted i LEFT JOIN deleted d ON i.location_id = d.location_id WHERE d.location_id IS NULL;

    INSERT INTO Audit_Log_Table (table_name, operation, record_id, changed_by, details)
    SELECT @TableName, 'UPDATE', i.location_id, SYSTEM_USER, CONCAT('Location Updated: ', i.city, ', ', i.country)
    FROM inserted i INNER JOIN deleted d ON i.location_id = d.location_id;

    INSERT INTO Audit_Log_Table (table_name, operation, record_id, changed_by, details)
    SELECT @TableName, 'DELETE', d.location_id, SYSTEM_USER, CONCAT('Location Deleted: ', i.city, ', ', i.country)
    FROM deleted d LEFT JOIN inserted i ON d.location_id = i.location_id WHERE i.location_id IS NULL;
END;
GO

-- 1.4 Role Dimension Audit
CREATE OR ALTER TRIGGER trg_Role_Audit
ON Role_Dimension_Table
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @TableName NVARCHAR(255) = 'Role_Dimension_Table';

    INSERT INTO Audit_Log_Table (table_name, operation, record_id, changed_by, details)
    SELECT @TableName, 'INSERT', i.role_id, SYSTEM_USER, 'Role Added: ' + i.role_name
    FROM inserted i LEFT JOIN deleted d ON i.role_id = d.role_id WHERE d.role_id IS NULL;

    INSERT INTO Audit_Log_Table (table_name, operation, record_id, changed_by, details)
    SELECT @TableName, 'UPDATE', i.role_id, SYSTEM_USER, 'Role Updated: ' + i.role_name
    FROM inserted i INNER JOIN deleted d ON i.role_id = d.role_id;

    INSERT INTO Audit_Log_Table (table_name, operation, record_id, changed_by, details)
    SELECT @TableName, 'DELETE', d.role_id, SYSTEM_USER, 'Role Deleted: ' + d.role_name
    FROM deleted d LEFT JOIN inserted i ON d.role_id = i.role_id WHERE i.role_id IS NULL;
END;
GO

-- 1.5 Portal Dimension Audit
CREATE OR ALTER TRIGGER trg_Portal_Audit
ON Portal_Dimension_Table
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @TableName NVARCHAR(255) = 'Portal_Dimension_Table';

    INSERT INTO Audit_Log_Table (table_name, operation, record_id, changed_by, details)
    SELECT @TableName, 'INSERT', i.portal_id, SYSTEM_USER, 'Portal Added: ' + i.portal_name
    FROM inserted i LEFT JOIN deleted d ON i.portal_id = d.portal_id WHERE d.portal_id IS NULL;

    INSERT INTO Audit_Log_Table (table_name, operation, record_id, changed_by, details)
    SELECT @TableName, 'UPDATE', i.portal_id, SYSTEM_USER, 'Portal Updated: ' + i.portal_name
    FROM inserted i INNER JOIN deleted d ON i.portal_id = d.portal_id;

    INSERT INTO Audit_Log_Table (table_name, operation, record_id, changed_by, details)
    SELECT @TableName, 'DELETE', d.portal_id, SYSTEM_USER, 'Portal Deleted: ' + d.portal_name
    FROM deleted d LEFT JOIN inserted i ON d.portal_id = i.portal_id WHERE i.portal_id IS NULL;
END;
GO

-- 1.6 Skill Dimension Audit
CREATE OR ALTER TRIGGER trg_Skill_Audit
ON Skill_Dimension_Table
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @TableName NVARCHAR(255) = 'Skill_Dimension_Table';

    INSERT INTO Audit_Log_Table (table_name, operation, record_id, changed_by, details)
    SELECT @TableName, 'INSERT', i.skill_id, SYSTEM_USER, 'Skill Added: ' + i.skill_name
    FROM inserted i LEFT JOIN deleted d ON i.skill_id = d.skill_id WHERE d.skill_id IS NULL;

    INSERT INTO Audit_Log_Table (table_name, operation, record_id, changed_by, details)
    SELECT @TableName, 'UPDATE', i.skill_id, SYSTEM_USER, 'Skill Updated: ' + i.skill_name
    FROM inserted i INNER JOIN deleted d ON i.skill_id = d.skill_id;

    INSERT INTO Audit_Log_Table (table_name, operation, record_id, changed_by, details)
    SELECT @TableName, 'DELETE', d.skill_id, SYSTEM_USER, 'Skill Deleted: ' + d.skill_name
    FROM deleted d LEFT JOIN inserted i ON d.skill_id = i.skill_id WHERE i.skill_id IS NULL;
END;
GO

-- 1.7 Date Dimension Audit
CREATE OR ALTER TRIGGER trg_Date_Audit
ON Date_Dimension_Table
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @TableName NVARCHAR(255) = 'Date_Dimension_Table';

    INSERT INTO Audit_Log_Table (table_name, operation, record_id, changed_by, details)
    SELECT @TableName, 'INSERT', i.date_id, SYSTEM_USER, 'Date Added: ' + CAST(i.full_date AS NVARCHAR)
    FROM inserted i LEFT JOIN deleted d ON i.date_id = d.date_id WHERE d.date_id IS NULL;

    INSERT INTO Audit_Log_Table (table_name, operation, record_id, changed_by, details)
    SELECT @TableName, 'UPDATE', i.date_id, SYSTEM_USER, 'Date Updated: ' + CAST(i.full_date AS NVARCHAR)
    FROM inserted i INNER JOIN deleted d ON i.date_id = d.date_id;

    INSERT INTO Audit_Log_Table (table_name, operation, record_id, changed_by, details)
    SELECT @TableName, 'DELETE', d.date_id, SYSTEM_USER, 'Date Deleted: ' + CAST(d.full_date AS NVARCHAR)
    FROM deleted d LEFT JOIN inserted i ON d.date_id = i.date_id WHERE i.date_id IS NULL;
END;
GO