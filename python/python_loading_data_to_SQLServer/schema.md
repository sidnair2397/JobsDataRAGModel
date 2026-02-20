# ETL Pipeline Documentation

## Overview

This Python script implements an ETL (Extract, Transform, Load) pipeline that:

1. **Extracts** job description data from Databricks
2. **Transforms** the data using Azure AI Language services (sentiment analysis, key phrase extraction, entity recognition)
3. **Loads** the enriched data into SQL Server using stored procedures

---

## Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Databricks    │     │   Azure AI      │     │   SQL Server    │
│   (Source)      │────▶│   Language      │────▶│   (Target)      │
│                 │     │   Services      │     │                 │
└─────────────────┘     └─────────────────┘     └─────────────────┘
        │                       │                       │
        ▼                       ▼                       ▼
   job_descriptions      - Sentiment Analysis      - Dimension Tables
   table (1.6M rows)     - Key Phrase Extraction   - Fact Table
                         - Entity Recognition      - Bridge Tables
                                                   - NLP Tables
```

---

## Prerequisites

### Python Packages

```bash
pip install pandas pyodbc python-dotenv databricks-sdk databricks-sql-connector azure-ai-textanalytics
```

### Environment Variables

Create a `.env` file in the project root:

```env
# Databricks
DATABRICKS_SERVER_HOSTNAME=your-workspace.cloud.databricks.com
DATABRICKS_HTTP_PATH=/sql/1.0/warehouses/your-warehouse-id
DATABRICKS_TOKEN=your-databricks-token

# Azure AI Language
LanguageServiceEndpoint=https://your-resource.cognitiveservices.azure.com/
LanguageServiceAPI=your-api-key

# SQL Server
SQL_SERVER=your-server.database.windows.net
SQL_DATABASE=JobMarketDB
SQL_USERNAME=your-username
SQL_PASSWORD=your-password
```

### SQL Server Setup

Ensure the following database objects exist:
- Dimension tables (Company, Location, Role, Portal, Date, Skill)
- Fact table (Job_Fact_Table)
- Bridge table (Job_Skill_Bridge_Table)
- NLP tables (Job_Key_Phrase_Table, Job_Entity_Table)
- Stored procedures (sp_UpsertJob, sp_GetOrCreate*, sp_SyncJob*)
- Functions (fn_ParseSalaryMin, fn_ParseSalaryMax, fn_ClassifySentiment, fn_CleanBenefits, fn_SplitSkills)

---

## Functions

### Authentication Functions

#### `authenticate_azure_client()`
Authenticates with Azure AI Language services.

- **Returns:** `TextAnalyticsClient`
- **Raises:** `ValueError` if credentials are missing

#### `authenticate_databricks_client()`
Authenticates with Databricks workspace.

- **Returns:** `WorkspaceClient`
- **Raises:** `ValueError` if authentication fails

#### `connect_to_sql_server()`
Establishes connection to SQL Server.

- **Returns:** `pyodbc.Connection`
- **Raises:** `ValueError` if credentials are missing

---

### Data Loading Functions

#### `load_data_from_databricks(catalog_name, schema_name, table_name)`
Loads data from a Databricks table into a Pandas DataFrame.

| Parameter | Type | Description |
|-----------|------|-------------|
| catalog_name | str | Databricks catalog name |
| schema_name | str | Schema name |
| table_name | str | Table name |

- **Returns:** `pd.DataFrame`

#### `random_df_split(df, numrows)`
Returns a random sample of the DataFrame.

| Parameter | Type | Description |
|-----------|------|-------------|
| df | pd.DataFrame | Source DataFrame |
| numrows | int | Number of rows to sample |

- **Returns:** `pd.DataFrame`
- **Raises:** `ValueError` if numrows exceeds DataFrame length

---

### NLP Analysis Functions

#### `analyze_sentiment(azure_client, df, text_column, batch_size=5)`
Analyzes sentiment for text in a DataFrame column.

| Parameter | Type | Description |
|-----------|------|-------------|
| azure_client | TextAnalyticsClient | Authenticated client |
| df | pd.DataFrame | DataFrame with text |
| text_column | str | Column name to analyze |
| batch_size | int | Documents per API call (max 5) |

- **Returns:** `pd.DataFrame` with `sentiment_score` and `sentiment_label` columns added

#### `extract_key_phrases(azure_client, df, text_column, batch_size=5)`
Extracts key phrases from text.

| Parameter | Type | Description |
|-----------|------|-------------|
| azure_client | TextAnalyticsClient | Authenticated client |
| df | pd.DataFrame | DataFrame with text |
| text_column | str | Column name to analyze |
| batch_size | int | Documents per API call (max 5) |

- **Returns:** `pd.DataFrame` with columns: `job_id`, `phrase`, `source_field`

#### `recognize_entities(azure_client, df, text_column, batch_size=5)`
Recognizes named entities from text.

| Parameter | Type | Description |
|-----------|------|-------------|
| azure_client | TextAnalyticsClient | Authenticated client |
| df | pd.DataFrame | DataFrame with text |
| text_column | str | Column name to analyze |
| batch_size | int | Documents per API call (max 5) |

- **Returns:** `pd.DataFrame` with columns: `job_id`, `entity_name`, `entity_type`, `confidence`

#### `run_all_nlp_analysis(azure_client, df, text_column='Job Description')`
Runs all three NLP analyses in sequence.

| Parameter | Type | Description |
|-----------|------|-------------|
| azure_client | TextAnalyticsClient | Authenticated client |
| df | pd.DataFrame | DataFrame with text |
| text_column | str | Column name to analyze |

- **Returns:** `tuple(df_with_sentiment, df_key_phrases, df_entities)`

---

### SQL Loading Functions

#### `upsert_job_to_sql(conn, row, df_key_phrases, df_entities)`
Inserts or updates a single job record using `sp_UpsertJob`.

| Parameter | Type | Description |
|-----------|------|-------------|
| conn | pyodbc.Connection | SQL Server connection |
| row | pd.Series | Single job record |
| df_key_phrases | pd.DataFrame | All key phrases |
| df_entities | pd.DataFrame | All entities |

- **Returns:** `job_id`

**Internal process:**
1. Filters key phrases and entities for the specific job
2. Converts data to JSON format
3. Converts numpy types to Python native types
4. Calls `sp_UpsertJob` stored procedure

#### `load_all_jobs_to_sql(conn, df_with_sentiment, df_key_phrases, df_entities)`
Batch loads all jobs into SQL Server.

| Parameter | Type | Description |
|-----------|------|-------------|
| conn | pyodbc.Connection | SQL Server connection |
| df_with_sentiment | pd.DataFrame | Jobs with sentiment |
| df_key_phrases | pd.DataFrame | All key phrases |
| df_entities | pd.DataFrame | All entities |

- **Returns:** `tuple(success_count, error_count)`

---

## Data Flow

### Input (Databricks)

Source table: `workspace.default.job_descriptions`

| Column | Type | Description |
|--------|------|-------------|
| Job Id | BIGINT | Unique identifier |
| Job Title | STRING | Job title |
| Company | STRING | Company name |
| Company Size | INT | Number of employees |
| Company Profile | STRING | JSON company details |
| location | STRING | City |
| Country | STRING | Country |
| latitude | FLOAT | GPS latitude |
| longitude | FLOAT | GPS longitude |
| Role | STRING | Job role |
| Job Portal | STRING | Source portal |
| Job Posting Date | DATE | Posting date |
| Salary Range | STRING | e.g., "$59K-$99K" |
| Experience | STRING | e.g., "3-5 years" |
| Qualifications | STRING | Required qualifications |
| Job Description | STRING | Full description |
| Benefits | STRING | Benefits list |
| Work Type | STRING | Remote/Hybrid/Onsite |
| Preference | STRING | Candidate preference |
| Contact Person | STRING | Contact name |
| Contact | STRING | Contact info |
| Responsibilities | STRING | Job responsibilities |
| skills | STRING | Comma-separated skills |

### Output (SQL Server)

#### Job_Fact_Table
Contains enriched job data with:
- All source fields
- Parsed salary (min/max)
- Cleaned benefits
- Sentiment score and label
- Foreign keys to dimension tables

#### Job_Skill_Bridge_Table
Many-to-many relationship between jobs and skills.

#### Job_Key_Phrase_Table
Key phrases extracted by Azure AI.

#### Job_Entity_Table
Named entities recognized by Azure AI.

---

## Azure AI Transaction Usage

### Free Tier Limits
- 5,000 transactions per month

### Transaction Calculation

| Operation | Transactions per Job |
|-----------|---------------------|
| Sentiment Analysis | 1 |
| Key Phrase Extraction | 1 |
| Entity Recognition | 1 |
| **Total** | **3** |

### Sample Size Guidelines

| Sample Size | Total Transactions | Within Free Tier? |
|-------------|-------------------|-------------------|
| 500 | 1,500 | ✅ Yes |
| 1,000 | 3,000 | ✅ Yes |
| 1,500 | 4,500 | ✅ Yes |
| 1,666 | 4,998 | ✅ Yes (max safe) |
| 2,000 | 6,000 | ❌ No |

---

## Usage

### Basic Execution

```bash
python main.py
```

### Expected Output

```
Azure Text Analytics Client authenticated successfully.
Databricks Client authenticated successfully. Connected to: https://your-workspace.cloud.databricks.com
SQL Server connected successfully.
SQL Server Version: Microsoft SQL Server 2022...

Running query: SELECT * FROM workspace.default.job_descriptions
Data loaded successfully from Databricks.

Running NLP analysis on 1500 documents...
--------------------------------------------------
[1/3] Analyzing sentiment...
Sentiment distribution:
Neutral     892
Positive    456
Negative    152

[2/3] Extracting key phrases...
Extracted 12847 key phrases from 1500 jobs.

[3/3] Recognizing entities...
Recognized 8934 entities from 1500 jobs.
--------------------------------------------------
NLP analysis complete!

Processing 1500 jobs...
--------------------------------------------------
  ✓ Processed 10/1500 jobs...
  ✓ Processed 20/1500 jobs...
  ...
  ✓ Processed 1500/1500 jobs...
--------------------------------------------------
Complete! Success: 1500, Errors: 0

==================================================
DATABASE SUMMARY
==================================================
  Jobs:        1500
  Skills:      4523
  Key Phrases: 12847
  Entities:    8934
==================================================
```

---

## Error Handling

### Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| `ODBC Driver not found` | Driver not installed | Install ODBC Driver 18 |
| `numpy.int64 invalid type` | Numpy type not converted | Use `to_python()` helper |
| `fn_SplitSkills not found` | Function missing in SQL | Create the function |
| `Login failed` | Wrong credentials | Check `.env` values |
| `Free tier exceeded` | Too many transactions | Reduce sample size |

### Retry Logic

The `load_all_jobs_to_sql` function:
- Continues processing on individual job failures
- Rolls back failed transactions
- Reports success/error counts at the end

---

## Performance Considerations

### Batch Sizes
- Azure AI: 5 documents per request (API limit)
- SQL Server: 1 job per `sp_UpsertJob` call

### Estimated Processing Time

| Sample Size | NLP Analysis | SQL Load | Total |
|-------------|--------------|----------|-------|
| 100 | ~2 min | ~1 min | ~3 min |
| 500 | ~10 min | ~5 min | ~15 min |
| 1,500 | ~30 min | ~15 min | ~45 min |

---

## Future Enhancements

1. **Parallel Processing**: Use multiprocessing for SQL inserts
2. **Batch SQL Inserts**: Use bulk insert instead of row-by-row
3. **Skill Categorization**: Integrate Gemini API for skill classification
4. **Incremental Loading**: Track processed jobs to avoid reprocessing
5. **Error Recovery**: Save progress to resume after failures
