/*
This file contains the SQL code for the stored procedure for the bridge and nlp tables in the database.
*/

-- Sync any changes to the JobSkills Bridge Table
CREATE OR ALTER PROCEDURE sp_SyncJobSkills
    @job_id BIGINT,
    @skills_string NVARCHAR(MAX) -- Comma-separated list (e.g., "SQL, Python, Azure")
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Parse the incoming CSV string into a temporary table
    --    Note: We must resolve skill names to IDs first.
    DECLARE @IncomingSkills TABLE (skill_id INT);

    INSERT INTO @IncomingSkills (skill_id)
    SELECT DISTINCT s.skill_id
    FROM dbo.fn_SplitSkills(@skills_string) input
    JOIN Skill_Dimension_Table s ON input.skill_name = s.skill_name;
    -- Note: This assumes sp_UpsertJob has already ensured all skills exist in the dimension.

    BEGIN TRY
        -- 2. The MERGE Sync
        --    Target: The existing links in the database
        --    Source: The new list of skills for this job
        MERGE Job_Skill_Bridge_Table WITH (HOLDLOCK) AS target
        USING (SELECT @job_id AS job_id, skill_id FROM @IncomingSkills) AS source
        ON target.job_id = source.job_id AND target.skill_id = source.skill_id

        WHEN NOT MATCHED BY TARGET THEN
            -- Insert a new skill found in input
            INSERT (job_id, skill_id)
            VALUES (source.job_id, source.skill_id)

        WHEN NOT MATCHED BY SOURCE AND target.job_id = @job_id THEN
            -- Delete any old skill found in DB but missing from input
            DELETE;
            
        -- No action on matched. The link already exists.

    END TRY
    BEGIN CATCH
        -- In case of deadlock, let the main orchestrator handle the retry
        THROW;
    END CATCH
END;
GO

-- Sync the key phrases for a job id
CREATE OR ALTER PROCEDURE sp_SyncJobKeyPhrases
    @job_id BIGINT,
    @phrases_json NVARCHAR(MAX) -- JSON Array: [{"phrase": "Data Engineering", "source": "Title"}, ...]
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        MERGE Job_Key_Phrase_Table WITH (HOLDLOCK) AS target
        USING (
            -- Parse JSON into a tabular format
            SELECT 
                @job_id AS job_id,
                JSON_VALUE(value, '$.phrase') AS phrase,
                ISNULL(JSON_VALUE(value, '$.source'), 'Description') AS source_field
            FROM OPENJSON(@phrases_json)
        ) AS source
        ON target.job_id = source.job_id AND target.phrase = source.phrase

        WHEN MATCHED THEN
            -- Update source_field if it changed (e.g., moved from Title to Desc)
            UPDATE SET source_field = source.source_field

        WHEN NOT MATCHED BY TARGET THEN
            -- Insert new phrase
            INSERT (job_id, phrase, source_field)
            VALUES (source.job_id, source.phrase, source.source_field)

        WHEN NOT MATCHED BY SOURCE AND target.job_id = @job_id THEN
            -- Remove old phrases no longer found in the analysis
            DELETE;

    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO


-- Sync the entities table
CREATE OR ALTER PROCEDURE sp_SyncJobEntities
    @job_id BIGINT,
    @entities_json NVARCHAR(MAX) -- JSON Array: [{"entity": "Google", "type": "Org", "confidence": 0.99}, ...]
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        MERGE Job_Entity_Table WITH (HOLDLOCK) AS target
        USING (
            SELECT 
                @job_id AS job_id,
                JSON_VALUE(value, '$.entity') AS entity_name,
                JSON_VALUE(value, '$.type') AS entity_type,
                CAST(JSON_VALUE(value, '$.confidence') AS DECIMAL(5,4)) AS confidence
            FROM OPENJSON(@entities_json)
        ) AS source
        ON target.job_id = source.job_id 
           AND target.entity_name = source.entity_name 
           AND target.entity_type = source.entity_type

        WHEN MATCHED THEN
            -- Update confidence score if the model improved it
            UPDATE SET confidence = source.confidence

        WHEN NOT MATCHED BY TARGET THEN
            INSERT (job_id, entity_name, entity_type, confidence)
            VALUES (source.job_id, source.entity_name, source.entity_type, source.confidence)

        WHEN NOT MATCHED BY SOURCE AND target.job_id = @job_id THEN
            DELETE;

    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO