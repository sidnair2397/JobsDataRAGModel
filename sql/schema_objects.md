# SQL Objects Specification

## Triggers

### trg_Job_Audit
- **Table:** Job_Fact_Table
- **Event:** AFTER INSERT, UPDATE, DELETE
- **Purpose:** Log all changes (inserts, updates, deletes) to the fact table in a single trigger using inserted/deleted pseudo-tables to determine operation type

### trg_Company_Audit
- **Table:** Company_Dimension_Table
- **Event:** AFTER INSERT, UPDATE, DELETE
- **Purpose:** Log all changes to company dimension for tracking new companies and modifications

### trg_Location_Audit
- **Table:** Location_Dimension_Table
- **Event:** AFTER INSERT, UPDATE, DELETE
- **Purpose:** Log all changes to location dimension for tracking new locations and modifications

### trg_Role_Audit
- **Table:** Role_Dimension_Table
- **Event:** AFTER INSERT, UPDATE, DELETE
- **Purpose:** Log all changes to role dimension for tracking new roles and modifications

### trg_Portal_Audit
- **Table:** Portal_Dimension_Table
- **Event:** AFTER INSERT, UPDATE, DELETE
- **Purpose:** Log all changes to portal dimension for tracking new job portals and modifications

### trg_Skill_Audit
- **Table:** Skill_Dimension_Table
- **Event:** AFTER INSERT, UPDATE, DELETE
- **Purpose:** Log all changes to skill dimension for tracking new skills and modifications

### trg_Date_Audit
- **Table:** Date_Dimension_Table
- **Event:** AFTER INSERT, UPDATE, DELETE
- **Purpose:** Log all changes to date dimension for tracking new dates and modifications

---

## Functions

### fn_ParseSalaryMin
- **Type:** Scalar
- **Input:** @salary_range NVARCHAR(255) (e.g., `$59K-$99K`)
- **Output:** DECIMAL(18,2) (e.g., `59000.00`)
- **Purpose:** Extract minimum salary from range string, remove `$` and `K`, multiply by 1000. Returns NULL if input is NULL or unparseable.

### fn_ParseSalaryMax
- **Type:** Scalar
- **Input:** @salary_range NVARCHAR(255) (e.g., `$59K-$99K`)
- **Output:** DECIMAL(18,2) (e.g., `99000.00`)
- **Purpose:** Extract maximum salary from range string, remove `$` and `K`, multiply by 1000. Returns NULL if input is NULL or unparseable.

### fn_ClassifySentiment
- **Type:** Scalar
- **Input:** @sentiment_score DECIMAL(5,4) (e.g., `0.72`)
- **Output:** NVARCHAR(10) (`Positive`, `Neutral`, or `Negative`)
- **Purpose:** Classify sentiment score into label — <0.4 = Negative, 0.4-0.6 = Neutral, >0.6 = Positive. Returns NULL if input is NULL.

### fn_CleanBenefits
- **Type:** Scalar
- **Input:** @benefits NVARCHAR(MAX) (e.g., `{'Health Insurance, Paid Time Off'}`)
- **Output:** NVARCHAR(MAX) (e.g., `Health Insurance, Paid Time Off`)
- **Purpose:** Remove curly braces and single quotes from benefits string for clean storage

### fn_GetSkillCount
- **Type:** Scalar
- **Input:** @job_id BIGINT
- **Output:** INT
- **Purpose:** Return the count of skills associated with a specific job from the bridge table

---

## Stored Procedures

### Dimension Table Procedures (GetOrCreate)

### sp_GetOrCreateCompany
- **Parameters:** @company_name NVARCHAR(255), @company_size INT, @company_profile NVARCHAR(MAX)
- **Returns:** @company_id INT (OUTPUT)
- **Calls:** None
- **Purpose:** MERGE pattern — check if company exists by name, return existing company_id or insert new record. Updates size/profile if record exists with ISNULL to preserve existing values.

### sp_GetOrCreateLocation
- **Parameters:** @city NVARCHAR(255), @country NVARCHAR(255), @latitude DECIMAL(9,6), @longitude DECIMAL(9,6)
- **Returns:** @location_id INT (OUTPUT)
- **Calls:** None
- **Purpose:** MERGE pattern — check if location exists by city and country combination, return existing location_id or insert new record. Updates lat/long if record exists.

### sp_GetOrCreateRole
- **Parameters:** @role_name NVARCHAR(255)
- **Returns:** @role_id INT (OUTPUT)
- **Calls:** None
- **Purpose:** MERGE pattern — check if role exists by name, return existing role_id or insert new record.

### sp_GetOrCreatePortal
- **Parameters:** @portal_name NVARCHAR(255)
- **Returns:** @portal_id INT (OUTPUT)
- **Calls:** None
- **Purpose:** MERGE pattern — check if portal exists by name, return existing portal_id or insert new record.

### sp_GetOrCreateDate
- **Parameters:** @posting_date DATE
- **Returns:** @date_id INT (OUTPUT)
- **Calls:** None
- **Purpose:** MERGE pattern — check if date exists, return existing date_id or insert new record with derived fields (year, month, day_of_week).

### sp_GetOrCreateSkill
- **Parameters:** @skill_name NVARCHAR(255), @skill_category NVARCHAR(MAX)
- **Returns:** @skill_id INT (OUTPUT)
- **Calls:** None
- **Purpose:** MERGE pattern — check if skill exists by name, return existing skill_id or insert new record with category. Updates category if record exists using ISNULL to preserve existing values.

### Sync Procedures (Bridge & NLP Tables)

### sp_SyncJobSkills
- **Parameters:** @job_id BIGINT, @skills_json NVARCHAR(MAX) (JSON array: `[{"skill_name": "SQL", "skill_category": "Programming"}, ...]`)
- **Returns:** None
- **Calls:** None (assumes skills already exist in Skill_Dimension_Table)
- **Purpose:** MERGE pattern with NOT MATCHED BY SOURCE — syncs skills for a job by inserting new skill associations and deleting removed ones in a single operation.

### sp_SyncJobKeyPhrases
- **Parameters:** @job_id BIGINT, @phrases_json NVARCHAR(MAX) (JSON array: `[{"phrase": "Data Engineering", "source": "Title"}, ...]`)
- **Returns:** None
- **Calls:** None
- **Purpose:** MERGE pattern with NOT MATCHED BY SOURCE — syncs key phrases for a job from Azure AI output. Inserts new phrases, updates source_field if changed, deletes removed phrases.

### sp_SyncJobEntities
- **Parameters:** @job_id BIGINT, @entities_json NVARCHAR(MAX) (JSON array: `[{"entity": "Google", "type": "Org", "confidence": 0.99}, ...]`)
- **Returns:** None
- **Calls:** None
- **Purpose:** MERGE pattern with NOT MATCHED BY SOURCE — syncs entities for a job from Azure AI output. Inserts new entities, updates confidence if changed, deletes removed entities.

---

## Views

### vw_JobDetails
- **Purpose:** Denormalized view of jobs with all dimension attributes for comprehensive job listing
- **Joins:** Job_Fact_Table + Company_Dimension_Table + Location_Dimension_Table + Role_Dimension_Table + Portal_Dimension_Table + Date_Dimension_Table
- **Key Columns:** job_id, job_title, company_name, city, country, role_name, portal_name, full_date, experience, qualifications, salary_min, salary_max, work_type, preference, benefits, responsibilities, sentiment_score, sentiment_label

### vw_JobWithSkills
- **Purpose:** Jobs with associated skills aggregated as comma-separated list for skill-based job search
- **Joins:** Job_Fact_Table + Job_Skill_Bridge_Table + Skill_Dimension_Table
- **Key Columns:** job_id, job_title, skills_list (STRING_AGG of skill_name), skill_count

### vw_SkillDemand
- **Purpose:** Skills ranked by frequency of appearance in job postings for market demand analysis
- **Joins:** Skill_Dimension_Table + Job_Skill_Bridge_Table
- **Key Columns:** skill_id, skill_name, job_count, demand_rank (ROW_NUMBER)

### vw_SalaryByRole
- **Purpose:** Salary statistics aggregated by role for compensation benchmarking
- **Joins:** Job_Fact_Table + Role_Dimension_Table
- **Key Columns:** role_id, role_name, avg_salary_min, avg_salary_max, min_salary, max_salary, job_count

### vw_SalaryByLocation
- **Purpose:** Salary statistics aggregated by location for geographic compensation analysis
- **Joins:** Job_Fact_Table + Location_Dimension_Table
- **Key Columns:** location_id, city, country, avg_salary_min, avg_salary_max, min_salary, max_salary, job_count

### vw_SentimentByCompany
- **Purpose:** Average sentiment scores and distribution by company for employer brand analysis
- **Joins:** Job_Fact_Table + Company_Dimension_Table
- **Key Columns:** company_id, company_name, avg_sentiment_score, positive_count, neutral_count, negative_count, job_count

### vw_SentimentByRole
- **Purpose:** Average sentiment scores and distribution by role for role satisfaction analysis
- **Joins:** Job_Fact_Table + Role_Dimension_Table
- **Key Columns:** role_id, role_name, avg_sentiment_score, positive_count, neutral_count, negative_count, job_count

### vw_JobsByLocation
- **Purpose:** Job posting counts and trends by geographic location for market distribution analysis
- **Joins:** Job_Fact_Table + Location_Dimension_Table
- **Key Columns:** location_id, city, country, latitude, longitude, job_count

### vw_JobsByPortal
- **Purpose:** Job posting distribution across job portals for source analysis
- **Joins:** Job_Fact_Table + Portal_Dimension_Table
- **Key Columns:** portal_id, portal_name, job_count, avg_salary_min, avg_salary_max

### vw_JobPostingTrend
- **Purpose:** Job posting counts over time for trend analysis
- **Joins:** Job_Fact_Table + Date_Dimension_Table
- **Key Columns:** date_id, full_date, year, month, day_of_week, job_count

### vw_JobKeyPhrases
- **Purpose:** Jobs with associated key phrases for NLP-based search and analysis
- **Joins:** Job_Fact_Table + Job_Key_Phrase_Table
- **Key Columns:** job_id, job_title, phrase, source_field

### vw_JobEntities
- **Purpose:** Jobs with associated named entities for entity-based filtering and analysis
- **Joins:** Job_Fact_Table + Job_Entity_Table
- **Key Columns:** job_id, job_title, entity_name, entity_type, confidence

---

## Indexes

### IX_Job_Company
- **Table:** Job_Fact_Table
- **Type:** Non-Clustered
- **Columns:** company_id
- **Include:** job_title, salary_min, salary_max, sentiment_label
- **Purpose:** Optimize queries filtering jobs by company with commonly selected columns covered

### IX_Job_Location
- **Table:** Job_Fact_Table
- **Type:** Non-Clustered
- **Columns:** location_id
- **Include:** job_title, work_type, salary_min, salary_max
- **Purpose:** Optimize queries filtering jobs by location with commonly selected columns covered

### IX_Job_Role
- **Table:** Job_Fact_Table
- **Type:** Non-Clustered
- **Columns:** role_id
- **Include:** job_title, experience, salary_min, salary_max
- **Purpose:** Optimize queries filtering jobs by role with commonly selected columns covered

### IX_Job_Portal
- **Table:** Job_Fact_Table
- **Type:** Non-Clustered
- **Columns:** portal_id
- **Include:** job_title, company_id, date_id
- **Purpose:** Optimize queries filtering jobs by portal source

### IX_Job_Date
- **Table:** Job_Fact_Table
- **Type:** Non-Clustered
- **Columns:** date_id
- **Include:** job_title, company_id, role_id
- **Purpose:** Optimize queries filtering jobs by posting date range for trend analysis

### IX_Job_Sentiment
- **Table:** Job_Fact_Table
- **Type:** Non-Clustered
- **Columns:** sentiment_label
- **Include:** job_title, company_id, role_id
- **Purpose:** Optimize queries filtering jobs by sentiment classification

### IX_Job_WorkType
- **Table:** Job_Fact_Table
- **Type:** Non-Clustered
- **Columns:** work_type
- **Include:** job_title, salary_min, salary_max, location_id
- **Purpose:** Optimize queries filtering jobs by work type (Full-time, Part-time, Intern, etc.)

### IX_Bridge_Job
- **Table:** Job_Skill_Bridge_Table
- **Type:** Non-Clustered
- **Columns:** job_id
- **Include:** skill_id
- **Purpose:** Optimize lookups of all skills for a specific job (used by vw_JobWithSkills)

### IX_Bridge_Skill
- **Table:** Job_Skill_Bridge_Table
- **Type:** Non-Clustered
- **Columns:** skill_id
- **Include:** job_id
- **Purpose:** Optimize lookups of all jobs requiring a specific skill (used by vw_SkillDemand)

### IX_Company_Name
- **Table:** Company_Dimension_Table
- **Type:** Non-Clustered Unique
- **Columns:** company_name
- **Include:** company_size
- **Purpose:** Optimize company lookup by name in sp_GetOrCreateCompany and enforce uniqueness

### IX_Location_CityCountry
- **Table:** Location_Dimension_Table
- **Type:** Non-Clustered Unique
- **Columns:** city, country
- **Include:** latitude, longitude
- **Purpose:** Optimize location lookup by city and country combination in sp_GetOrCreateLocation and enforce uniqueness

### IX_Role_Name
- **Table:** Role_Dimension_Table
- **Type:** Non-Clustered Unique
- **Columns:** role_name
- **Purpose:** Optimize role lookup by name in sp_GetOrCreateRole and enforce uniqueness

### IX_Portal_Name
- **Table:** Portal_Dimension_Table
- **Type:** Non-Clustered Unique
- **Columns:** portal_name
- **Purpose:** Optimize portal lookup by name in sp_GetOrCreatePortal and enforce uniqueness

### IX_Skill_Name
- **Table:** Skill_Dimension_Table
- **Type:** Non-Clustered Unique
- **Columns:** skill_name
- **Purpose:** Optimize skill lookup by name in sp_GetOrCreateSkill and enforce uniqueness

### IX_Date_FullDate
- **Table:** Date_Dimension_Table
- **Type:** Non-Clustered Unique
- **Columns:** full_date
- **Purpose:** Optimize date lookup by full_date in sp_GetOrCreateDate and enforce uniqueness

### IX_Date_YearMonth
- **Table:** Date_Dimension_Table
- **Type:** Non-Clustered
- **Columns:** year, month
- **Include:** date_id, full_date
- **Purpose:** Optimize queries filtering by year and month for trend analysis

### IX_KeyPhrase_Job
- **Table:** Job_Key_Phrase_Table
- **Type:** Non-Clustered
- **Columns:** job_id
- **Include:** phrase, source_field
- **Purpose:** Optimize lookup of all key phrases for a specific job

### IX_KeyPhrase_Phrase
- **Table:** Job_Key_Phrase_Table
- **Type:** Non-Clustered
- **Columns:** phrase
- **Include:** job_id
- **Purpose:** Optimize search for jobs containing a specific key phrase

### IX_Entity_Job
- **Table:** Job_Entity_Table
- **Type:** Non-Clustered
- **Columns:** job_id
- **Include:** entity_name, entity_type, confidence
- **Purpose:** Optimize lookup of all entities for a specific job

### IX_Entity_Type
- **Table:** Job_Entity_Table
- **Type:** Non-Clustered
- **Columns:** entity_type
- **Include:** job_id, entity_name
- **Purpose:** Optimize filtering entities by type (e.g., Organization, Location, Person)

### IX_Audit_Table
- **Table:** Audit_Log_Table
- **Type:** Non-Clustered
- **Columns:** table_name
- **Include:** operation, record_id, changed_at
- **Purpose:** Optimize audit queries filtering by table name

### IX_Audit_Date
- **Table:** Audit_Log_Table
- **Type:** Non-Clustered
- **Columns:** changed_at
- **Include:** table_name, operation, record_id
- **Purpose:** Optimize audit queries filtering by date range