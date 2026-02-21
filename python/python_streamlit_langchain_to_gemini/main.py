'''
Streamlit Chat Interface for Job Market Intelligence Platform
RAG Pipeline using LangChain + Gemini + SQL Server
'''
import os
import streamlit as st
from dotenv import load_dotenv
from urllib.parse import quote_plus
from sqlalchemy import create_engine
from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_community.utilities import SQLDatabase
from langchain_community.agent_toolkits import create_sql_agent

# Page configuration
st.set_page_config(
    page_title="Job Market Intelligence",
    page_icon="💼",
    layout="wide"
)

# Custom CSS
st.markdown("""
<style>
    .main-header {
        font-size: 2.5rem;
        font-weight: bold;
        color: #1E88E5;
        text-align: center;
        margin-bottom: 0.5rem;
    }
    .sub-header {
        font-size: 1.1rem;
        color: #666;
        text-align: center;
        margin-bottom: 2rem;
    }
    .stButton > button {
        width: 100%;
    }
</style>
""", unsafe_allow_html=True)


@st.cache_resource
def connect_to_sql_database():
    '''
    Creates a LangChain SQLDatabase connection to SQL Server using pyodbc.
    Cached to avoid reconnecting on every interaction.
    '''
    load_dotenv()
    
    server = os.getenv("SQL_SERVER")
    database = os.getenv("SQL_DATABASE")
    username = os.getenv("SQL_USERNAME")
    password = os.getenv("SQL_PASSWORD")
    
    if not all([server, database, username, password]):
        raise ValueError("Missing SQL Server credentials in .env file.")
    
    # Build pyodbc connection string
    connection_string = (
        f"DRIVER={{ODBC Driver 18 for SQL Server}};"
        f"SERVER={server};"
        f"DATABASE={database};"
        f"UID={username};"
        f"PWD={password};"
        f"TrustServerCertificate=yes;"
        f"Connection Timeout=60;"
    )
    
    # Create SQLAlchemy engine using pyodbc connection string
    engine = create_engine(
        f"mssql+pyodbc:///?odbc_connect={quote_plus(connection_string)}"
    )
    
    # Create LangChain SQLDatabase from engine
    db = SQLDatabase(engine)
    
    return db


@st.cache_resource
def create_gemini_sql_agent(_db):
    '''
    Creates a LangChain SQL Agent using Gemini as the LLM.
    Cached to avoid recreating on every interaction.
    '''
    load_dotenv()
    
    llm = ChatGoogleGenerativeAI(
        model="gemini-2.5-flash",
        google_api_key=os.getenv("GOOGLE_API_KEY"),
        temperature=0
    )
    
    custom_prompt = """
    You are an expert SQL data analyst for a Job Market Intelligence Platform.
    
    When asked a question:
    1. First look at the relevant tables using sql_db_schema
    2. Write a SQL query to answer the question
    3. Execute the query using sql_db_query
    4. Return a clear, formatted answer based on the results
    
    Available tables:
    - Job_Fact_Table: Job postings with titles, salaries, sentiment scores
    - Company_Dimension_Table: Company information
    - Location_Dimension_Table: City and country data
    - Role_Dimension_Table: Job roles
    - Skill_Dimension_Table: Skills with categories
    - Job_Skill_Bridge_Table: Links jobs to skills (many-to-many)
    - Job_Key_Phrase_Table: Key phrases from job descriptions
    - Job_Entity_Table: Named entities from job descriptions
    
    Available views (use these for simpler queries):
    - vw_JobDetails: Denormalized job data
    - vw_SkillDemand: Skills ranked by demand
    - vw_SalaryByRole: Salary statistics by role
    - vw_SalaryByLocation: Salary statistics by location
    - vw_SentimentByCompany: Sentiment by company
    
    Always execute queries - never just describe what you would do.
    Limit results to 20 rows unless asked otherwise.
    Format numbers clearly (e.g., salaries as currency).
    """
    
    agent = create_sql_agent(
        llm=llm,
        db=_db,
        agent_type="tool-calling",
        verbose=False,  # Set to False for cleaner Streamlit output
        prefix=custom_prompt,
        max_iterations=15,
        handle_parsing_errors=True
    )
    
    return agent


def query_database(agent, question):
    '''
    Queries the database using natural language.
    '''
    try:
        response = agent.invoke({"input": question})
        return response["output"], None
    except Exception as e:
        return None, str(e)


def get_database_stats(db):
    '''
    Gets basic statistics from the database.
    '''
    try:
        job_count = db.run("SELECT COUNT(*) FROM Job_Fact_Table")
        company_count = db.run("SELECT COUNT(*) FROM Company_Dimension_Table")
        skill_count = db.run("SELECT COUNT(*) FROM Skill_Dimension_Table")
        location_count = db.run("SELECT COUNT(*) FROM Location_Dimension_Table")
        
        # Clean up the results
        def clean_count(val):
            if val:
                return val.strip("[](),").split(",")[0].strip()
            return "0"
        
        return {
            "jobs": clean_count(job_count),
            "companies": clean_count(company_count),
            "skills": clean_count(skill_count),
            "locations": clean_count(location_count)
        }
    except:
        return {"jobs": "N/A", "companies": "N/A", "skills": "N/A", "locations": "N/A"}


def main():
    # Header
    st.markdown('<p class="main-header">💼 Job Market Intelligence Platform</p>', unsafe_allow_html=True)
    st.markdown('<p class="sub-header">Ask questions about job postings, salaries, skills, and market trends</p>', unsafe_allow_html=True)
    
    # Initialize session state for chat history
    if "messages" not in st.session_state:
        st.session_state.messages = []
    
    if "db_connected" not in st.session_state:
        st.session_state.db_connected = False
    
    # Initialize database connection
    with st.spinner("Connecting to database..."):
        try:
            db = connect_to_sql_database()
            agent = create_gemini_sql_agent(db)
            st.session_state.db_connected = True
        except Exception as e:
            st.error(f"❌ Database connection failed: {e}")
            return
    
    # Sidebar
    with st.sidebar:
        st.header("📊 Database Overview")
        
        if st.session_state.db_connected:
            stats = get_database_stats(db)
            
            col1, col2 = st.columns(2)
            with col1:
                st.metric("Jobs", stats["jobs"])
                st.metric("Skills", stats["skills"])
            with col2:
                st.metric("Companies", stats["companies"])
                st.metric("Locations", stats["locations"])
        
        st.divider()
        
        st.header("💡 Sample Questions")
        sample_questions = [
            "What are the top 10 most in-demand skills?",
            "Show average salary by job role",
            "Which companies have the most job postings?",
            "What is the sentiment distribution across jobs?",
            "List top 5 jobs with highest salary",
            "Show job counts by country",
            "What are the most common job titles?",
            "Compare salaries between work types"
        ]
        
        for q in sample_questions:
            if st.button(q, key=f"sample_{q}", use_container_width=True):
                st.session_state.pending_question = q
        
        st.divider()
        
        st.header("📋 Available Tables")
        tables = db.get_usable_table_names()
        for table in sorted(tables):
            if table.startswith("vw_"):
                st.text(f"📊 {table}")
            else:
                st.text(f"📁 {table}")
        
        st.divider()
        
        # Clear chat button
        if st.button("🗑️ Clear Chat History", use_container_width=True):
            st.session_state.messages = []
            st.rerun()
    
    # Main chat interface
    st.header("🔍 Chat")
    
    # Display chat history
    for message in st.session_state.messages:
        with st.chat_message(message["role"]):
            st.markdown(message["content"])
    
    # Check for pending question from sidebar
    if "pending_question" in st.session_state:
        prompt = st.session_state.pending_question
        del st.session_state.pending_question
        
        # Add user message to chat
        st.session_state.messages.append({"role": "user", "content": prompt})
        with st.chat_message("user"):
            st.markdown(prompt)
        
        # Get response
        with st.chat_message("assistant"):
            with st.spinner("🤔 Analyzing..."):
                response, error = query_database(agent, prompt)
            
            if error:
                st.error(f"❌ Error: {error}")
                st.session_state.messages.append({"role": "assistant", "content": f"Error: {error}"})
            else:
                st.markdown(response)
                st.session_state.messages.append({"role": "assistant", "content": response})
        
        st.rerun()
    
    # Chat input
    if prompt := st.chat_input("Ask a question about the job market..."):
        # Add user message to chat
        st.session_state.messages.append({"role": "user", "content": prompt})
        with st.chat_message("user"):
            st.markdown(prompt)
        
        # Get response
        with st.chat_message("assistant"):
            with st.spinner("🤔 Analyzing..."):
                response, error = query_database(agent, prompt)
            
            if error:
                st.error(f"❌ Error: {error}")
                st.session_state.messages.append({"role": "assistant", "content": f"Error: {error}"})
            else:
                st.markdown(response)
                st.session_state.messages.append({"role": "assistant", "content": response})
    
    # Footer
    st.markdown("---")
    st.markdown(
        """
        <div style="text-align: center; color: #888; font-size: 0.85rem;">
            Built with Streamlit • Powered by Gemini AI • Data from Azure SQL Server<br>
            CS 779 Advanced Database Management - Job Market Intelligence Platform
        </div>
        """,
        unsafe_allow_html=True
    )


if __name__ == "__main__":
    main()