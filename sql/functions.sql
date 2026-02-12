/* 
SCALAR FUNCTIONS
Utility functions for data cleaning and parsing.
*/

-- Parse Minimum Salary: "$59K-$99K" -> 59000.00
CREATE OR ALTER FUNCTION fn_ParseSalaryMin(@salary_range NVARCHAR(255))
RETURNS DECIMAL(18,2)
AS
BEGIN
    IF @salary_range IS NULL RETURN NULL;
    
    DECLARE @Cleaned NVARCHAR(255) = REPLACE(REPLACE(REPLACE(UPPER(@salary_range), '$', ''), 'K', ''), ' ', '');
    DECLARE @HyphenIndex INT = CHARINDEX('-', @Cleaned);
    
    IF @HyphenIndex > 0
        RETURN TRY_CAST(LEFT(@Cleaned, @HyphenIndex - 1) AS DECIMAL(18,2)) * 1000;
    
    RETURN NULL;
END;
GO

-- Parse Maximum Salary: "$59K-$99K" -> 99000.00
CREATE OR ALTER FUNCTION fn_ParseSalaryMax(@salary_range NVARCHAR(255))
RETURNS DECIMAL(18,2)
AS
BEGIN
    IF @salary_range IS NULL RETURN NULL;
    
    DECLARE @Cleaned NVARCHAR(255) = REPLACE(REPLACE(REPLACE(UPPER(@salary_range), '$', ''), 'K', ''), ' ', '');
    DECLARE @HyphenIndex INT = CHARINDEX('-', @Cleaned);
    
    IF @HyphenIndex > 0
        RETURN TRY_CAST(SUBSTRING(@Cleaned, @HyphenIndex + 1, LEN(@Cleaned)) AS DECIMAL(18,2)) * 1000;
        
    RETURN NULL;
END;
GO

-- Classify Sentiment Score
CREATE OR ALTER FUNCTION fn_ClassifySentiment(@sentiment_score DECIMAL(5,4))
RETURNS NVARCHAR(10)
AS
BEGIN
    IF @sentiment_score IS NULL RETURN NULL;
    IF @sentiment_score < 0.4 RETURN 'Negative';
    IF @sentiment_score > 0.6 RETURN 'Positive';
    RETURN 'Neutral';
END;
GO

-- Clean Benefits: "{'Health Insurance', 'PTO'}" -> "Health Insurance, PTO"
CREATE OR ALTER FUNCTION fn_CleanBenefits(@benefits NVARCHAR(MAX))
RETURNS NVARCHAR(MAX)
AS
BEGIN
    RETURN REPLACE(REPLACE(REPLACE(@benefits, '{', ''), '}', ''), '''', '');
END;
GO

-- Get Skill Count for a specific Job
CREATE OR ALTER FUNCTION fn_GetSkillCount(@job_id BIGINT)
RETURNS INT
AS
BEGIN
    RETURN (SELECT COUNT(*) FROM Job_Skill_Bridge_Table WHERE job_id = @job_id);
END;
GO



