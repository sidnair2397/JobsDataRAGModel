/*
This file contains the SQL code for creating indexes in the database. 
*/

-- 3.1 Fact Table Foreign Keys (Critical for Joins)
CREATE NONCLUSTERED INDEX IX_Job_Company ON Job_Fact_Table(company_id) INCLUDE (job_title, salary_min, salary_max, sentiment_label);
CREATE NONCLUSTERED INDEX IX_Job_Location ON Job_Fact_Table(location_id) INCLUDE (job_title, work_type, salary_min, salary_max);
CREATE NONCLUSTERED INDEX IX_Job_Role ON Job_Fact_Table(role_id) INCLUDE (job_title, experience, salary_min, salary_max);
CREATE NONCLUSTERED INDEX IX_Job_Portal ON Job_Fact_Table(portal_id) INCLUDE (job_title, company_id, date_id);
CREATE NONCLUSTERED INDEX IX_Job_Date ON Job_Fact_Table(date_id) INCLUDE (job_title, company_id, role_id);

-- 3.2 Fact Table Analytical Columns
CREATE NONCLUSTERED INDEX IX_Job_Sentiment ON Job_Fact_Table(sentiment_label) INCLUDE (job_title, company_id, role_id);
CREATE NONCLUSTERED INDEX IX_Job_WorkType ON Job_Fact_Table(work_type) INCLUDE (job_title, salary_min, salary_max, location_id);

-- 3.3 Bridge Table Indexes (Critical for vw_JobWithSkills and vw_SkillDemand)
CREATE NONCLUSTERED INDEX IX_Bridge_Job ON Job_Skill_Bridge_Table(job_id) INCLUDE (skill_id);
CREATE NONCLUSTERED INDEX IX_Bridge_Skill ON Job_Skill_Bridge_Table(skill_id) INCLUDE (job_id);

-- 3.4 Dimension Unique Indexes (For GetOrCreate Procedures)
CREATE UNIQUE NONCLUSTERED INDEX IX_Company_Name ON Company_Dimension_Table(company_name) INCLUDE (company_size);
CREATE UNIQUE NONCLUSTERED INDEX IX_Location_CityCountry ON Location_Dimension_Table(city, country) INCLUDE (latitude, longitude);
CREATE UNIQUE NONCLUSTERED INDEX IX_Role_Name ON Role_Dimension_Table(role_name);
CREATE UNIQUE NONCLUSTERED INDEX IX_Portal_Name ON Portal_Dimension_Table(portal_name);
CREATE UNIQUE NONCLUSTERED INDEX IX_Skill_Name ON Skill_Dimension_Table(skill_name);
CREATE UNIQUE NONCLUSTERED INDEX IX_Date_FullDate ON Date_Dimension_Table(full_date);

-- 3.5 Date Analysis Index
CREATE NONCLUSTERED INDEX IX_Date_YearMonth ON Date_Dimension_Table(year, month) INCLUDE (date_id, full_date);

-- 3.6 NLP Indexes
CREATE NONCLUSTERED INDEX IX_KeyPhrase_Job ON Job_Key_Phrase_Table(job_id) INCLUDE (phrase, source_field);
CREATE NONCLUSTERED INDEX IX_KeyPhrase_Phrase ON Job_Key_Phrase_Table(phrase) INCLUDE (job_id);
CREATE NONCLUSTERED INDEX IX_Entity_Job ON Job_Entity_Table(job_id) INCLUDE (entity_name, entity_type, confidence);
CREATE NONCLUSTERED INDEX IX_Entity_Type ON Job_Entity_Table(entity_type) INCLUDE (job_id, entity_name);

-- 3.7 Audit Log Indexes
CREATE NONCLUSTERED INDEX IX_Audit_Table ON Audit_Log_Table(table_name) INCLUDE (operation, record_id, changed_at);
CREATE NONCLUSTERED INDEX IX_Audit_Date ON Audit_Log_Table(changed_at) INCLUDE (table_name, operation, record_id);

-- 3.8 Composite Key for Job and Location
CREATE NONCLUSTERED INDEX IX_Job_Role_Location ON Job_Fact_Table(role_id, location_id) INCLUDE (job_title, salary_min, salary_max);

GO