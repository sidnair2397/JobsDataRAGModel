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
            -- A. New skill found in input -> INSERT IT
            INSERT (job_id, skill_id)
            VALUES (source.job_id, source.skill_id)

        WHEN NOT MATCHED BY SOURCE AND target.job_id = @job_id THEN
            -- B. Old skill found in DB but missing from input -> DELETE IT
            DELETE;
            
        -- C. Matched? Do nothing. The link already exists.

    END TRY
    BEGIN CATCH
        -- In case of deadlock, let the main orchestrator handle the retry
        THROW;
    END CATCH
END;
GO