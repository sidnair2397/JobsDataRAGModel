'''
Streamlit Chat Interface for Job Market Intelligence Platform
Using Groq (FREE) + LangChain + SQL Server
'''
import os
import time
import streamlit as st
from dotenv import load_dotenv
from urllib.parse import quote_plus
from sqlalchemy import create_engine
from langchain_groq import ChatGroq
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
    '''
    load_dotenv()
    
    server = os.getenv("SQL_SERVER")
    database = os.getenv("SQL_DATABASE")
    username = os.getenv("SQL_USERNAME")
    password = os.getenv("SQL_PASSWORD")
    
    if not all([server, database, username, password]):
        raise ValueError("Missing SQL Server credentials in .env file.")
    
    connection_string = (
        f"DRIVER={{ODBC Driver 18 for SQL Server}};"
        f"SERVER={server};"
        f"DATABASE={database};"
        f"UID={username};"
        f"PWD={password};"
        f"TrustServerCertificate=yes;"
        f"Connection Timeout=60;"
    )
    
    engine = create_engine(
        f"mssql+pyodbc:///?odbc_connect={quote_plus(connection_string)}"
    )
    
    db = SQLDatabase(engine)
    return db


@st.cache_resource
def create_groq_sql_agent(_db):
    '''
    Creates a LangChain SQL Agent using Groq (FREE).
    '''
    load_dotenv()
    
    # Groq with Llama 3 70B - FREE!
    llm = ChatGroq(
        model="llama-3.3-70b-versatile",
        api_key=os.getenv("GROQ_API_KEY"),
        temperature=0
    )
    
    custom_prompt = """
    You are an expert SQL data analyst for a Job Market Intelligence Platform.
    
    USE THESE VIEWS (they are pre-joined and faster):
    
    1. vw_SkillDemand (skill_id, skill_name, job_count, demand_rank)
       → For questions about popular/in-demand skills
    
    2. vw_SalaryByRole (role_id, role_name, avg_salary_min, avg_salary_max, job_count)
       → For questions about salaries by job role
    
    3. vw_SalaryByLocation (location_id, city, country, avg_salary_min, avg_salary_max, job_count)
       → For questions about salaries by location
    
    4. vw_SentimentByCompany (company_id, company_name, avg_sentiment_score, positive_count, neutral_count, negative_count, job_count)
       → For questions about companies
    
    5. vw_JobsByLocation (location_id, city, country, latitude, longitude, job_count)
       → For questions about jobs by location
    
    6. vw_JobDetails (job_id, job_title, company_name, city, country, role_name, salary_min, salary_max, work_type, sentiment_label)
       → For listing specific jobs
    
    RULES:
    - Use TOP 10 to limit results
    - Execute query immediately, don't just describe
    - Format output as a clean readable list
    """
    
    agent = create_sql_agent(
        llm=llm,
        db=_db,
        agent_type="tool-calling",
        verbose=False,
        prefix=custom_prompt,
        max_iterations=10,
        handle_parsing_errors=True
    )
    
    return agent


def query_database(agent, question):
    '''
    Queries the database using natural language.
    '''
    try:
        response = agent.invoke({"input": question})
        output = response["output"]
        
        # Clean up response if it's a list/dict format
        if isinstance(output, list):
            text_parts = []
            for item in output:
                if isinstance(item, dict) and 'text' in item:
                    text_parts.append(item['text'])
                else:
                    text_parts.append(str(item))
            return "\n".join(text_parts), None
        
        return str(output), None
        
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
    
    # Initialize session state
    if "messages" not in st.session_state:
        st.session_state.messages = []
    
    # Initialize database connection
    with st.spinner("Connecting to database..."):
        try:
            db = connect_to_sql_database()
            agent = create_groq_sql_agent(db)
        except Exception as e:
            st.error(f"❌ Connection failed: {e}")
            return
    
    # Sidebar
    with st.sidebar:
        st.header("📊 Database Overview")
        
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
            "Show job counts by country",
            "What are the top paying roles?",
        ]
        
        for q in sample_questions:
            if st.button(q, key=f"sample_{q}", use_container_width=True):
                st.session_state.pending_question = q
        
        st.divider()
        
        st.success("✅ Powered by Groq (FREE tier)")
        
        st.divider()
        
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
        
        st.session_state.messages.append({"role": "user", "content": prompt})
        with st.chat_message("user"):
            st.markdown(prompt)
        
        with st.chat_message("assistant"):
            with st.spinner("🤔 Analyzing..."):
                response, error = query_database(agent, prompt)
            
            if error:
                st.error(f"❌ {error}")
                st.session_state.messages.append({"role": "assistant", "content": f"Error: {error}"})
            else:
                st.markdown(response)
                st.session_state.messages.append({"role": "assistant", "content": response})
        
        st.rerun()
    
    # Chat input
    if prompt := st.chat_input("Ask a question about the job market..."):
        st.session_state.messages.append({"role": "user", "content": prompt})
        with st.chat_message("user"):
            st.markdown(prompt)
        
        with st.chat_message("assistant"):
            with st.spinner("🤔 Analyzing..."):
                response, error = query_database(agent, prompt)
            
            if error:
                st.error(f"❌ {error}")
                st.session_state.messages.append({"role": "assistant", "content": f"Error: {error}"})
            else:
                st.markdown(response)
                st.session_state.messages.append({"role": "assistant", "content": response})
    
    # Footer
    st.markdown("---")
    st.markdown(
        """
        <div style="text-align: center; color: #888; font-size: 0.85rem;">
            CS 779 Advanced Database Management - Job Market Intelligence Platform<br>
            Powered by Groq Llama 3.3 70B (Free Tier)
        </div>
        """,
        unsafe_allow_html=True
    )


if __name__ == "__main__":
    main()