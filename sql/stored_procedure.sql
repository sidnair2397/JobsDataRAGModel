/*
This file contains the SQL code for the stored procedure in the database. 
*/

-- Dimension Table Stored Procedure (GetOrCreate)

-- Get or Create a Company in the Company Dimension Table
CREATE OR ALTER PROCEDURE sp_GetOrCreateCompany
    @company_name NVARCHAR(255),
    @company_size INT,
    @company_profile NVARCHAR(MAX),
    @company_id INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    -- Return the ID of the record inserted or updated 
    DECLARE @OutputTable TABLE (ReturnedID INT);

    BEGIN TRY
        -- Merge holds the company table and compares the target table with the new source values on company name (unique)
        MERGE Company_Dimension_Table WITH (HOLDLOCK) AS target
        USING (SELECT @company_name AS company_name, @company_size AS company_size, @company_profile AS company_profile) AS source
        ON target.company_name = source.company_name
        
        WHEN MATCHED THEN
            -- Overwrite old values with new ones from source
            -- We use ISNULL so if the source data is missing a size, we don't accidentally blank out an existing size
            UPDATE SET 
                company_size = ISNULL(source.company_size, target.company_size),
                company_profile = ISNULL(source.company_profile, target.company_profile)
                
        WHEN NOT MATCHED THEN
            -- Insert brand new company
            INSERT (company_name, company_size, company_profile)
            VALUES (source.company_name, source.company_size, source.company_profile)
            
        -- Capture the ID whether it was an UPDATE or an INSERT
        OUTPUT inserted.company_id INTO @OutputTable;

        -- Assign to the OUTPUT parameter
        SELECT TOP 1 
        @company_id = ReturnedID 
        FROM @OutputTable;

    END TRY
    BEGIN CATCH
        -- Catch any constraint violations 
        IF ERROR_NUMBER() IN (2627, 2601)
        BEGIN
            SELECT @company_id = company_id 
            FROM Company_Dimension_Table 
            WHERE company_name = @company_name;
        END
        ELSE
        BEGIN
            -- If it's a different error throw it 
            THROW;
        END
    END CATCH
END;
GO

-- Get or Create a Location in the Location Dimension Table
CREATE OR ALTER PROCEDURE sp_GetOrCreateLocation
    @city NVARCHAR(255),
    @country NVARCHAR(255),
    @latitude DECIMAL(9,6),
    @longitude DECIMAL(9,6),
    @location_id INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    -- Return the ID of the record inserted or updated 
    DECLARE @OutputTable TABLE (ReturnedID INT);

    BEGIN TRY
        -- Merge holds the location table and compares the target table with the new source values on combination of city and country
        MERGE Location_Dimension_Table WITH (HOLDLOCK) AS target
        USING (SELECT @city AS city, @country AS country, @latitude AS latitude, @longitude AS longitude) AS source
        ON target.city = source.city AND target.country = source.country

        WHEN MATCHED THEN
            -- Overwrite old values with new ones from source
            -- We use ISNULL so if the source data is missing a size, we don't accidentally blank out an existing size
            UPDATE SET
                latitude = ISNULL(source.latitude, target.latitude),
                longitude = ISNULL(source.longitude, target.longitude)

        WHEN NOT MATCHED THEN
            -- Insert brand new location
            INSERT (city, country, latitude, longitude) 
            VALUES (source.city, source.country, source.latitude, source.longitude) 

        -- Capture the ID whether it was an UPDATE or an INSERT
        OUTPUT inserted.location_id INTO @OutputTable;

        -- Assign to the OUTPUT parameter
        SELECT TOP 1
        @location_id = ReturnedID
        FROM @OutputTable;

    END TRY
    BEGIN CATCH
        -- Catch any constraint violations
        IF ERROR_NUMBER() IN (2627, 2601)
        BEGIN
            SELECT @location_id = location_id
            FROM Location_Dimension_Table
            WHERE city = @city AND country = @country;
        END
        ELSE
        BEGIN
            -- If it's a different error throw it
            THROW;
        END
    END CATCH
END;
GO

-- Get or Create a Role in the Role Dimension Table
CREATE OR ALTER PROCEDURE sp_GetOrCreateRole
    @role_name NVARCHAR(255),
    @role_id INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @OutputTable TABLE (ReturnedID INT);

    BEGIN TRY
        MERGE Role_Dimension_Table WITH (HOLDLOCK) AS target
        USING (SELECT @role_name AS role_name) AS source
        ON target.role_name = source.role_name

        WHEN MATCHED THEN
            -- No fields to update, but MERGE requires an action
            UPDATE SET role_name = target.role_name

        WHEN NOT MATCHED THEN
            INSERT (role_name)
            VALUES (source.role_name)

        OUTPUT inserted.role_id INTO @OutputTable;

        SELECT TOP 1 @role_id = ReturnedID FROM @OutputTable;

    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() IN (2627, 2601)
        BEGIN
            SELECT @role_id = role_id
            FROM Role_Dimension_Table
            WHERE role_name = @role_name;
        END
        ELSE
        BEGIN
            THROW;
        END
    END CATCH
END;
GO

-- Get or Create a Portal in the Portal Dimension Table
CREATE OR ALTER PROCEDURE sp_GetOrCreatePortal
    @portal_name NVARCHAR(255),
    @portal_id INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @OutputTable TABLE (ReturnedID INT);

    BEGIN TRY
        MERGE Portal_Dimension_Table WITH (HOLDLOCK) AS target
        USING (SELECT @portal_name AS portal_name) AS source
        ON target.portal_name = source.portal_name

        WHEN MATCHED THEN
            -- No fields to update, but MERGE requires an action
            UPDATE SET portal_name = target.portal_name

        WHEN NOT MATCHED THEN
            INSERT (portal_name)
            VALUES (source.portal_name)

        OUTPUT inserted.portal_id INTO @OutputTable;

        SELECT TOP 1 @portal_id = ReturnedID FROM @OutputTable;

    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() IN (2627, 2601)
        BEGIN
            SELECT @portal_id = portal_id
            FROM Portal_Dimension_Table
            WHERE portal_name = @portal_name;
        END
        ELSE
        BEGIN
            THROW;
        END
    END CATCH
END;
GO

-- Get or Create a Date in the Date Dimension Table
CREATE OR ALTER PROCEDURE sp_GetOrCreateDate
    @posting_date DATE,
    @date_id INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @OutputTable TABLE (ReturnedID INT);

    BEGIN TRY
        MERGE Date_Dimension_Table WITH (HOLDLOCK) AS target
        USING (
            SELECT 
                @posting_date AS full_date,
                DATENAME(MONTH, @posting_date) AS month,
                YEAR(@posting_date) AS year,
                DATENAME(WEEKDAY, @posting_date) AS day_of_week
        ) AS source
        ON target.full_date = source.full_date

        WHEN MATCHED THEN
            -- Date attributes are derived, but update in case of corrections
            UPDATE SET
                month = source.month,
                year = source.year,
                day_of_week = source.day_of_week

        WHEN NOT MATCHED THEN
            INSERT (full_date, month, year, day_of_week)
            VALUES (source.full_date, source.month, source.year, source.day_of_week)

        OUTPUT inserted.date_id INTO @OutputTable;

        SELECT TOP 1 @date_id = ReturnedID FROM @OutputTable;

    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() IN (2627, 2601)
        BEGIN
            SELECT @date_id = date_id
            FROM Date_Dimension_Table
            WHERE full_date = @posting_date;
        END
        ELSE
        BEGIN
            THROW;
        END
    END CATCH
END;
GO

-- Get or Create a Skill in the Skill Dimension Table
CREATE OR ALTER PROCEDURE sp_GetOrCreateSkill
    @skill_name NVARCHAR(255),
    @skill_category NVARCHAR(MAX),
    @skill_id INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @OutputTable TABLE (ReturnedID INT);

    BEGIN TRY
        MERGE Skill_Dimension_Table WITH (HOLDLOCK) AS target
        USING (SELECT @skill_name AS skill_name, @skill_category AS skill_category) AS source
        ON target.skill_name = source.skill_name

        WHEN MATCHED THEN
            -- Update category if new value provided (append or replace based on your needs)
            UPDATE SET
                skill_category = ISNULL(source.skill_category, target.skill_category)

        WHEN NOT MATCHED THEN
            INSERT (skill_name, skill_category)
            VALUES (source.skill_name, source.skill_category)

        OUTPUT inserted.skill_id INTO @OutputTable;

        SELECT TOP 1 @skill_id = ReturnedID FROM @OutputTable;

    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() IN (2627, 2601)
        BEGIN
            SELECT @skill_id = skill_id
            FROM Skill_Dimension_Table
            WHERE skill_name = @skill_name;
        END
        ELSE
        BEGIN
            THROW;
        END
    END CATCH
END;
GO