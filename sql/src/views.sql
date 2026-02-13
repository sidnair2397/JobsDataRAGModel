/*
This file contains the SQL code for creating views in the database. 
*/

-- 2.1 Comprehensive Job Details
CREATE OR ALTER VIEW vw_JobDetails AS
SELECT 
    j.job_id, j.job_title, 
    c.company_name, c.company_size,
    l.city, l.country, 
    r.role_name, 
    p.portal_name, 
    d.full_date,
    j.experience, j.qualifications, 
    j.salary_min, j.salary_max, 
    j.work_type, j.preference, 
    j.benefits, j.responsibilities, 
    j.sentiment_score, j.sentiment_label
FROM Job_Fact_Table j
LEFT JOIN Company_Dimension_Table c ON j.company_id = c.company_id
LEFT JOIN Location_Dimension_Table l ON j.location_id = l.location_id
LEFT JOIN Role_Dimension_Table r ON j.role_id = r.role_id
LEFT JOIN Portal_Dimension_Table p ON j.portal_id = p.portal_id
LEFT JOIN Date_Dimension_Table d ON j.date_id = d.date_id;
GO

-- 2.2 Jobs with Skills (Aggregated)
CREATE OR ALTER VIEW vw_JobWithSkills AS
SELECT 
    j.job_id, 
    j.job_title, 
    STRING_AGG(s.skill_name, ', ') WITHIN GROUP (ORDER BY s.skill_name) AS skills_list,
    COUNT(s.skill_id) AS skill_count
FROM Job_Fact_Table j
JOIN Job_Skill_Bridge_Table b ON j.job_id = b.job_id
JOIN Skill_Dimension_Table s ON b.skill_id = s.skill_id
GROUP BY j.job_id, j.job_title;
GO

-- 2.3 Skill Demand Ranking
CREATE OR ALTER VIEW vw_SkillDemand AS
SELECT 
    s.skill_id, 
    s.skill_name, 
    COUNT(b.job_id) AS job_count,
    ROW_NUMBER() OVER (ORDER BY COUNT(b.job_id) DESC) AS demand_rank
FROM Skill_Dimension_Table s
JOIN Job_Skill_Bridge_Table b ON s.skill_id = b.skill_id
GROUP BY s.skill_id, s.skill_name;
GO

-- 2.4 Salary By Role
CREATE OR ALTER VIEW vw_SalaryByRole AS
SELECT 
    r.role_id, r.role_name,
    AVG(j.salary_min) AS avg_salary_min,
    AVG(j.salary_max) AS avg_salary_max,
    MIN(j.salary_min) AS min_salary,
    MAX(j.salary_max) AS max_salary,
    COUNT(j.job_id) AS job_count
FROM Job_Fact_Table j
JOIN Role_Dimension_Table r ON j.role_id = r.role_id
GROUP BY r.role_id, r.role_name;
GO

-- 2.5 Salary By Location
CREATE OR ALTER VIEW vw_SalaryByLocation AS
SELECT 
    l.location_id, l.city, l.country,
    AVG(j.salary_min) AS avg_salary_min,
    AVG(j.salary_max) AS avg_salary_max,
    MIN(j.salary_min) AS min_salary,
    MAX(j.salary_max) AS max_salary,
    COUNT(j.job_id) AS job_count
FROM Job_Fact_Table j
JOIN Location_Dimension_Table l ON j.location_id = l.location_id
GROUP BY l.location_id, l.city, l.country;
GO

-- 2.6 Sentiment By Company
CREATE OR ALTER VIEW vw_SentimentByCompany AS
SELECT 
    c.company_id, c.company_name,
    AVG(j.sentiment_score) AS avg_sentiment_score,
    SUM(CASE WHEN j.sentiment_label = 'Positive' THEN 1 ELSE 0 END) AS positive_count,
    SUM(CASE WHEN j.sentiment_label = 'Neutral' THEN 1 ELSE 0 END) AS neutral_count,
    SUM(CASE WHEN j.sentiment_label = 'Negative' THEN 1 ELSE 0 END) AS negative_count,
    COUNT(j.job_id) AS job_count
FROM Job_Fact_Table j
JOIN Company_Dimension_Table c ON j.company_id = c.company_id
GROUP BY c.company_id, c.company_name;
GO

-- 2.7 Sentiment By Role
CREATE OR ALTER VIEW vw_SentimentByRole AS
SELECT 
    r.role_id, r.role_name,
    AVG(j.sentiment_score) AS avg_sentiment_score,
    SUM(CASE WHEN j.sentiment_label = 'Positive' THEN 1 ELSE 0 END) AS positive_count,
    SUM(CASE WHEN j.sentiment_label = 'Neutral' THEN 1 ELSE 0 END) AS neutral_count,
    SUM(CASE WHEN j.sentiment_label = 'Negative' THEN 1 ELSE 0 END) AS negative_count,
    COUNT(j.job_id) AS job_count
FROM Job_Fact_Table j
JOIN Role_Dimension_Table r ON j.role_id = r.role_id
GROUP BY r.role_id, r.role_name;
GO

-- 2.8 Jobs By Location (Map Data)
CREATE OR ALTER VIEW vw_JobsByLocation AS
SELECT 
    l.location_id, l.city, l.country, l.latitude, l.longitude,
    COUNT(j.job_id) AS job_count
FROM Job_Fact_Table j
JOIN Location_Dimension_Table l ON j.location_id = l.location_id
GROUP BY l.location_id, l.city, l.country, l.latitude, l.longitude;
GO

-- 2.9 Jobs By Portal
CREATE OR ALTER VIEW vw_JobsByPortal AS
SELECT 
    p.portal_id, p.portal_name,
    COUNT(j.job_id) AS job_count,
    AVG(j.salary_min) AS avg_salary_min,
    AVG(j.salary_max) AS avg_salary_max
FROM Job_Fact_Table j
JOIN Portal_Dimension_Table p ON j.portal_id = p.portal_id
GROUP BY p.portal_id, p.portal_name;
GO

-- 2.10 Job Posting Trend
CREATE OR ALTER VIEW vw_JobPostingTrend AS
SELECT 
    d.date_id, d.full_date, d.year, d.month, d.day_of_week,
    MONTH(d.full_date) AS month_number,
    COUNT(j.job_id) AS job_count
FROM Job_Fact_Table j
JOIN Date_Dimension_Table d ON j.date_id = d.date_id
GROUP BY d.date_id, d.full_date, d.year, d.month, d.day_of_week;
GO

-- 2.11 NLP Key Phrases
CREATE OR ALTER VIEW vw_JobKeyPhrases AS
SELECT 
    j.job_id, j.job_title, kp.phrase, kp.source_field
FROM Job_Fact_Table j
JOIN Job_Key_Phrase_Table kp ON j.job_id = kp.job_id;
GO

-- 2.12 NLP Entities
CREATE OR ALTER VIEW vw_JobEntities AS
SELECT 
    j.job_id, j.job_title, e.entity_name, e.entity_type, e.confidence
FROM Job_Fact_Table j
JOIN Job_Entity_Table e ON j.job_id = e.job_id;
GO