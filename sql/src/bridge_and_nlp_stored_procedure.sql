/*
This file contains the SQL code for the stored procedure for the bridge and nlp tables in the database.
*/

-- Sync any changes to the JobSkills Bridge Table
CREATE OR ALTER PROCEDURE sp_SyncJobSkills
    @job_id BIGINT,
    @skills_string NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    -- Handle NULL or empty input
    IF @skills_string IS NULL OR LEN(TRIM(@skills_string)) = 0
        RETURN;

    DECLARE @IncomingSkills TABLE (skill_id INT);
    DECLARE @skill_name NVARCHAR(255);
    DECLARE @skill_id INT;

    BEGIN TRY
        -- Cursor to iterate through parsed skills
        DECLARE skill_cursor CURSOR LOCAL FAST_FORWARD FOR
            SELECT skill_name FROM dbo.fn_SplitSkills(@skills_string);

        OPEN skill_cursor;
        FETCH NEXT FROM skill_cursor INTO @skill_name;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            -- Get or create each skill
            EXEC sp_GetOrCreateSkill 
                @skill_name = @skill_name,
                @skill_category = NULL,
                @skill_id = @skill_id OUTPUT;

            INSERT INTO @IncomingSkills (skill_id) VALUES (@skill_id);

            FETCH NEXT FROM skill_cursor INTO @skill_name;
        END

        CLOSE skill_cursor;
        DEALLOCATE skill_cursor;

        -- The MERGE Sync
        MERGE Job_Skill_Bridge_Table WITH (HOLDLOCK) AS target
        USING (SELECT @job_id AS job_id, skill_id FROM @IncomingSkills) AS source
        ON target.job_id = source.job_id AND target.skill_id = source.skill_id

        WHEN NOT MATCHED BY TARGET THEN
            INSERT (job_id, skill_id)
            VALUES (source.job_id, source.skill_id)

        WHEN NOT MATCHED BY SOURCE AND target.job_id = @job_id THEN
            DELETE;

    END TRY
    BEGIN CATCH
        -- Clean up cursor if still open
        IF CURSOR_STATUS('local', 'skill_cursor') = 1
        BEGIN
            CLOSE skill_cursor;
        END
        IF CURSOR_STATUS('local', 'skill_cursor') = -1
        BEGIN
            DEALLOCATE skill_cursor;
        END
        
        -- Re-throw the error
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
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