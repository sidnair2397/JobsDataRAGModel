/*
Dimension Tables
Tables that are referenced by the fact table.
*/

-- Company Dimension
CREATE TABLE Company_Dimension_Table (
    company_id INT IDENTITY(1,1) PRIMARY KEY,   -- Primary Key, Auto-increment
    company_name NVARCHAR(255) NOT NULL,                 -- Assuming standard name length
    company_size INT,
    company_profile NVARCHAR(MAX)               -- MAX used for potentially long descriptions
);

-- Location Dimension
CREATE TABLE Location_Dimension_Table (
    location_id INT IDENTITY(1,1) PRIMARY KEY,  -- Primary Key, Auto-increment
    city NVARCHAR(255) NOT NULL,
    country NVARCHAR(255) NOT NULL,
    latitude DECIMAL(9, 6),                     -- Standard precision for GPS coordinates
    longitude DECIMAL(9, 6)
);

-- Role Dimension
CREATE TABLE Role_Dimension_Table (
    role_id INT IDENTITY(1,1) PRIMARY KEY,      -- Primary Key, Auto-increment
    role_name NVARCHAR(255) NOT NULL
);

-- Portal Dimension
CREATE TABLE Portal_Dimension_Table (
    portal_id INT IDENTITY(1,1) PRIMARY KEY,    -- Primary Key, Auto-increment
    portal_name NVARCHAR(255) NOT NULL
);

-- Date Dimension
CREATE TABLE Date_Dimension_Table (
    date_id INT IDENTITY(1,1) PRIMARY KEY,      -- Primary Key, Auto-increment
    full_date DATE,
    month NVARCHAR(20),                         -- e.g., "January"
    year INT,
    day_of_week NVARCHAR(20)                    -- e.g., "Monday"
);

-- Skill Dimension
CREATE TABLE Skill_Dimension_Table (
    skill_id INT IDENTITY(1,1) PRIMARY KEY,     -- Primary Key, Auto-increment
    skill_name NVARCHAR(255) NOT NULL,
    skill_category NVARCHAR(500)
);

/*
Fact Table
Central table referencing the dimensions above.
*/

CREATE TABLE Job_Fact_Table (
    job_id BIGINT PRIMARY KEY,                  -- Primary Key, pre-created in the data pipeline
    -- Foreign Keys linking to Dimensions
    company_id INT,
    location_id INT,
    role_id INT,
    portal_id INT,
    date_id INT,
    -- Job Details
    job_title NVARCHAR(255),
    job_description NVARCHAR(MAX),             -- MAX for potentially long descriptions
    experience NVARCHAR(100),                   -- e.g., "3-5 years"
    qualifications NVARCHAR(MAX),               -- Likely a long string or list
    salary_min DECIMAL(18, 2),                  -- Standard currency precision
    salary_max DECIMAL(18, 2),
    work_type NVARCHAR(100),                    -- e.g., "Remote", "Hybrid"
    preference NVARCHAR(255),
    benefits NVARCHAR(MAX),
    contact_person NVARCHAR(255),
    contact_number NVARCHAR(50),
    responsibilities NVARCHAR(MAX),             -- Long text field
    -- Sentiment Analysis Data
    sentiment_score DECIMAL(5, 4),              -- Allowing for scores like 0.9876
    sentiment_label NVARCHAR(50),               -- e.g., "Positive", "Negative"
    -- Foreign Key Constraints
    CONSTRAINT FK_Job_Company FOREIGN KEY (company_id) REFERENCES Company_Dimension_Table(company_id),
    CONSTRAINT FK_Job_Location FOREIGN KEY (location_id) REFERENCES Location_Dimension_Table(location_id),
    CONSTRAINT FK_Job_Role FOREIGN KEY (role_id) REFERENCES Role_Dimension_Table(role_id),
    CONSTRAINT FK_Job_Portal FOREIGN KEY (portal_id) REFERENCES Portal_Dimension_Table(portal_id),
    CONSTRAINT FK_Job_Date FOREIGN KEY (date_id) REFERENCES Date_Dimension_Table(date_id)
);

/*
Bridge and Dependent Tables
Tables that reference the Job Fact Table or handle Many-to-Many relationships.
*/

-- Job-Skill Bridge Table (Handles Many-to-Many relationship between Jobs and Skills)
CREATE TABLE Job_Skill_Bridge_Table (
    job_skill_id INT IDENTITY(1,1) PRIMARY KEY,
    job_id BIGINT,                              -- FK to Job Fact
    skill_id INT,                               -- FK to Skill Dimension

    CONSTRAINT FK_Bridge_Job FOREIGN KEY (job_id) REFERENCES Job_Fact_Table(job_id),
    CONSTRAINT FK_Bridge_Skill FOREIGN KEY (skill_id) REFERENCES Skill_Dimension_Table(skill_id)
);

-- Job Key Phrase Table (NLP Output)
CREATE TABLE Job_Key_Phrase_Table (
    phrase_id INT IDENTITY(1,1) PRIMARY KEY,
    job_id BIGINT,                              -- FK to Job Fact
    phrase NVARCHAR(255),
    source_field NVARCHAR(255),                 -- Which field the phrase came from

    CONSTRAINT FK_Phrase_Job FOREIGN KEY (job_id) REFERENCES Job_Fact_Table(job_id)
);

-- Job Entity Table (NLP Output)
CREATE TABLE Job_Entity_Table (
    entity_id INT IDENTITY(1,1) PRIMARY KEY,
    job_id BIGINT,                              -- FK to Job Fact
    entity_name NVARCHAR(255),
    entity_type NVARCHAR(100),                  -- e.g., "Organization", "Person"
    confidence DECIMAL(5, 4),                   -- Confidence score (0-1)

    CONSTRAINT FK_Entity_Job FOREIGN KEY (job_id) REFERENCES Job_Fact_Table(job_id)
);

/*
Audit Table
Standalone table for tracking system changes.
*/

CREATE TABLE Audit_Log_Table (
    log_id INT IDENTITY(1,1) PRIMARY KEY,
    table_name NVARCHAR(255),
    operation NVARCHAR(50),                     -- e.g., "INSERT", "UPDATE", "DELETE"
    record_id BIGINT,                           -- ID of the record changed
    changed_by NVARCHAR(255),                   -- User or System Process ID
    changed_at DATETIME DEFAULT GETDATE(),      -- Auto-timestamp
    details NVARCHAR(MAX)                       -- JSON or text description of change
);