# JobsDataRAGModel

## About This Project
This is my final project for the Boston University MET CS 779 coursework on Advanced Database Management. As the course name suggests, the primary focus is on SQL schema design and database interactions. 
However, I also wanted to leverage this opportunity to explore additional skills that are highly relevant in today's job market.

**Skills Developed**

- Advanced SQL Concepts:
  - Star schema design with BCNF normalization
  - Covered indexes and query optimization
  - Triggers for audit logging
  - Stored procedures and user-defined functions
  - Integration with AI/ML pipelines
- Distributed Database Concepts
- Data processing with Databricks (PySpark)
- Python Libraries
  - PySpark for distributed data transformation
  - LangChain for RAG pipeline orchestration
  - Streamlit for interactive chat UI
  - Google Gemini API for natural language generation
- Azure AI Services
  - Sentiment analysis
  - Key phrase extraction
  - Named entity recognition

## Project Description
I am building a Job Market Intelligence Platform — a natural language interface that allows users to query job market data conversationally.

Proof of Concept:
- Ingest ~1,500 job postings from Kaggle (https://www.kaggle.com/datasets/ravindrasinghrana/job-description-dataset)
- Enrich data using Azure AI Language (sentiment analysis, key phrase extraction, named entity recognition)
- Store in a normalized SQL Server database with advanced database objects 
- Build a RAG (Retrieval-Augmented Generation) pipeline using LangChain + Gemini 1.5
- Deploy a Streamlit chat interface where users can ask questions like "What skills are most in-demand for AI Engineers in Texas?" and receive data-grounded answers

The POC demonstrates end-to-end data flow: **Raw Data → Processing → NLP enrichment → Relational Storage → Intelligent Querying**
