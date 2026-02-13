/*
This file contains the SQL code for creating fact table stored procedure in the database. 
*/

-- Upsert Stored Procedure
CREATE OR ALTER PROCEDURE sp_UpsertJob
    @job_id BIGINT,
    @job_title NVARCHAR(255),
    @company_name NVARCHAR(255),
    @company_size INT,
    @company_profile NVARCHAR(MAX),
    @city NVARCHAR(255),
    @country NVARCHAR(255),
    @latitude DECIMAL(9,6),
    @longitude DECIMAL(9,6),
    @role_name NVARCHAR(255),
    @portal_name NVARCHAR(255),
    @posting_date DATE,
    @salary_range NVARCHAR(255),
    @experience NVARCHAR(100),
    @qualifications NVARCHAR(MAX),
    @job_description NVARCHAR(MAX),
    @benefits NVARCHAR(MAX),
    @work_type NVARCHAR(100),
    @preference NVARCHAR(255),
    @contact_person NVARCHAR(255),
    @contact_number NVARCHAR(50),
    @responsibilities NVARCHAR(MAX),
    @skills_string NVARCHAR(MAX),       -- Comma-separated string
    @key_phrases_json NVARCHAR(MAX),    -- JSON Array from Azure AI
    @entities_json NVARCHAR(MAX),       -- JSON Array from Azure AI
    @sentiment_score DECIMAL(5,4)
AS
BEGIN
    SET NOCOUNT ON;
    
    -- 1. Declare Dimension ID Variables
    DECLARE @company_id INT, @location_id INT, @role_id INT, @portal_id INT, @date_id INT;

    -- 2. Resolve Dimensions (Get ID if exists, Create if not)
    EXEC sp_GetOrCreateCompany @company_name, @company_size, @company_profile, @company_id OUTPUT;
    EXEC sp_GetOrCreateLocation @city, @country, @latitude, @longitude, @location_id OUTPUT;
    EXEC sp_GetOrCreateRole @role_name, @role_id OUTPUT;
    EXEC sp_GetOrCreatePortal @portal_name, @portal_id OUTPUT;
    EXEC sp_GetOrCreateDate @posting_date, @date_id OUTPUT;

    -- 3. Parse Derived Fields using Scalar Functions
    DECLARE @salary_min DECIMAL(18,2) = dbo.fn_ParseSalaryMin(@salary_range);
    DECLARE @salary_max DECIMAL(18,2) = dbo.fn_ParseSalaryMax(@salary_range);
    DECLARE @clean_benefits NVARCHAR(MAX) = dbo.fn_CleanBenefits(@benefits);
    DECLARE @sentiment_label NVARCHAR(50) = dbo.fn_ClassifySentiment(@sentiment_score);

    BEGIN TRY
        -- 4. MERGE into Fact Table (Upsert Logic)
        MERGE Job_Fact_Table WITH (HOLDLOCK) AS target
        USING (SELECT @job_id AS job_id) AS source
        ON target.job_id = source.job_id

        WHEN MATCHED THEN
            -- Update existing job (SCD Type 1)
            UPDATE SET 
                company_id = @company_id,
                location_id = @location_id,
                role_id = @role_id,
                portal_id = @portal_id,
                date_id = @date_id,
                job_title = ISNULL(@job_title, target.job_title),
                job_description = ISNULL(@job_description, target.job_description),
                experience = ISNULL(@experience, target.experience),
                qualifications = ISNULL(@qualifications, target.qualifications),
                salary_min = ISNULL(@salary_min, target.salary_min),
                salary_max = ISNULL(@salary_max, target.salary_max),
                work_type = ISNULL(@work_type, target.work_type),
                preference = ISNULL(@preference, target.preference),
                benefits = ISNULL(@clean_benefits, target.benefits),
                contact_person = ISNULL(@contact_person, target.contact_person),
                contact_number = ISNULL(@contact_number, target.contact_number),
                responsibilities = ISNULL(@responsibilities, target.responsibilities),
                sentiment_score = ISNULL(@sentiment_score, target.sentiment_score),
                sentiment_label = ISNULL(@sentiment_label, target.sentiment_label)

        WHEN NOT MATCHED THEN
            -- Insert new job
            INSERT (
                job_id, company_id, location_id, role_id, portal_id, date_id,
                job_title, job_description, experience, qualifications,
                salary_min, salary_max, work_type, preference, benefits,
                contact_person, contact_number, responsibilities,
                sentiment_score, sentiment_label
            )
            VALUES (
                @job_id, @company_id, @location_id, @role_id, @portal_id, @date_id,
                @job_title, @job_description, @experience, @qualifications,
                @salary_min, @salary_max, @work_type, @preference, @clean_benefits,
                @contact_person, @contact_number, @responsibilities,
                @sentiment_score, @sentiment_label
            );

        -- 5. Sync Dependent Tables (Bridge & NLP)
        -- These procedures handle the Delete/Insert logic efficiently
        EXEC sp_SyncJobSkills @job_id, @skills_string;
        EXEC sp_SyncJobKeyPhrases @job_id, @key_phrases_json;
        EXEC sp_SyncJobEntities @job_id, @entities_json;

    END TRY
    BEGIN CATCH
        -- In case of blocking or deadlock, re-throw to the Python pipeline for retry
        THROW;
    END CATCH
END;
GO

-- Delete Stored Procedure
CREATE OR ALTER PROCEDURE sp_DeleteJob
    @job_id BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Delete Dependencies first (Cascade Logic)
        -- We must clear the child tables before the parent Fact table
        DELETE FROM Job_Skill_Bridge_Table WHERE job_id = @job_id;
        DELETE FROM Job_Key_Phrase_Table WHERE job_id = @job_id;
        DELETE FROM Job_Entity_Table WHERE job_id = @job_id;

        -- 2. Delete from Fact Table
        DELETE FROM Job_Fact_Table WHERE job_id = @job_id;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        -- If anything fails, roll back everything so we don't have partial deletes
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

