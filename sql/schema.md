# Schema

## Fields in the chosen dataset

The Kaggle Dataset (https://www.kaggle.com/datasets/ravindrasinghrana/job-description-dataset) contain the following fields:
- **Job Identifiers:** Job ID, Job Title, Role
- **Company Data:** Company Name, Company Size, Company Profile
- **Location Data:** Location, Country, Latitude, Longitude
- **Job Details:** Experience, Qualifications, Salary Range, Work Type, Benefits,
- **Rich text for NLP:** Job Description, Skills, Responsibilities
- **Metadata:** Job Posting Date, Job Portal, Contact Person

Processing Plan:
- Process ~1500 records (within Azure AI free tier: 5K transactions/month)
- Parse skills column into normalized skill entities
- Extract sentiment, key phrases, and named entities from Job Description

## Planned Tables
### Dimension Tables
- **Company_Dimension_Table**
	- comapny_id: INT (PK)
 	- company_name: NVARCHAR
  	- company_size: INT
  	- company_profile: NVARCHAR
- **Location_Dimension_Table**
	- location_id: INT (PK)
 	- city: NVARCHAR
  	- country: NVARCHAR
  	- latitude: DECIMAL
  	- longitude: DECIMAL
- **Role_Dimension_Table**
	- role_id: INT (PK)
 	- role_name: NVARCHAR
  	- role_category: NVARCHAR
- **Portal_Dimension_Table**
	- portal_id: INT (PK)
 	- portal_name: NVARCHAR
- **Skill_Dimension_Table**
	- skill_id: INT (PK)
 	- skill_name: NVARCHAR
  	- skill_category: NVARCHAR
- **Date_Dimension_Table**
	- date_id (PK)
 	- full_date: DATE
  	- month: NVARCHAR
  	- year: INT
  	- day_of_week: NVARCHAR 
          
### Fact Table
- **Job_Fact_Table**
	- job_id: BIGINT (PK)
 	- company_id: INT (FK1)
  	- location_id: INT (FK2)
  	- role_id: INT (FK3)
  	- portal_id: INT (FK4)
  	- date_id: INT (FK5)
  	- job_title: NVARCHAR
  	- experience: NVARCHAR
  	- qualifications: NVARCHAR
  	- salary_min: DECIMAL
  	- salary_max: DECIMAL
  	- work_type: NVARCHAR
  	- preference: NVARCHAR
  	- benefits: NVARCHAR
  	- responsibilities: NVARCHAR
  	- sentiment_score: DECIMAL
  	- sentiment_label: NVARCHAR

### Bridge Tables
- **Job_Skill_Bridge_Table**
	- job_skill_id: INT (PK)
 	- job_id: BIGINT (FK1)
  	- skill_id: NVARCHAR (FK2)

### NLP Tables
- **Job_Key_Phrase_Table**
	- phrase_id: INT (PK)
 	- job_id: BIGINT (FK1)
  	- phrase: NVARCHAR 
  	- source_field: NVARCHAR

- **Job_Entity_Table**
	- entity_id: INT (PK)
 	- job_id: BIGINT (FK1)
  	- entity_name: NVARCHAR
  	- entity_type: NVARCHAR
  	- confidence: DECIMAL     

### Audit Table
- **Audit_Log_Table**
	- log_id: INT (PK)
 	- table_name: NVARCHAR
  	- operation: NVARCHAR
  	- record_id: INT
  	- changed_by: NVARCHAR
  	- changed_at: DATETIME
  	- details: NVARCHAR  
## ERD Diagram
![MET CS 779 - Project ERD Diagram](https://github.com/user-attachments/assets/0ca8836c-4c15-40f5-9ecd-5189f2293d24)


