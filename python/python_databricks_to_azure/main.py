'''
Docstring for python.python_databricks_to_azure.main
'''
import os
import databricks.sdk as databricks
import pandas as pd
from dotenv import load_dotenv
from databricks import sql
from azure.ai.textanalytics import TextAnalyticsClient
from azure.core.credentials import AzureKeyCredential


def authenticate_azure_client():
    '''
    Authenticates the client for Azure Text Analytics API using credentials from .env file.
    Returns:
    TextAnalyticsClient: An authenticated client for Azure Text Analytics API.
    '''
    load_dotenv()  # Load environment variables from .env file
    endpoint = os.getenv("LanguageServiceEndpoint")
    api_key = os.getenv("LanguageServiceAPI")
    
    if not endpoint or not api_key:
        raise ValueError("Please set the LanguageServiceEndpoint and LanguageServiceAPI in the .env file.")
    
    return TextAnalyticsClient(endpoint=endpoint, credential=AzureKeyCredential(api_key))


def authenticate_databricks_client():
    '''
    Authenticates the Databricks WorkspaceClient using variables from the .env file.
    '''
    load_dotenv()  # Load environment variables from .env file
    w = databricks.WorkspaceClient()
    
    if not w:
        raise ValueError("Failed to authenticate with Databricks. Please check your credentials in the .env file.")
    
    return w


def load_data_from_databricks(catalog_name, schema_name, table_name):
    '''
    Loads data from a specified Databricks table into a Pandas DataFrame.
    '''
    connection = sql.connect(
        server_hostname=os.getenv("DATABRICKS_SERVER_HOSTNAME"),
        http_path=os.getenv("DATABRICKS_HTTP_PATH"),
        access_token=os.getenv("DATABRICKS_TOKEN")
    )
    
    query = f"SELECT * FROM {catalog_name}.{schema_name}.{table_name}"
    print(f"Running query: {query}")
    
    cursor = connection.cursor()
    cursor.execute(query)
    
    # Fetch all rows and column names
    columns = [desc[0] for desc in cursor.description]
    data = cursor.fetchall()
    
    cursor.close()
    connection.close()
    
    return pd.DataFrame(data, columns=columns)


def main():
    '''
    Main function to authenticate the client and perform text analytics operations.
    '''
    #Authenticate Azure Text Analytics Client
    try:
        azure_client = authenticate_azure_client()
        print("Azure Text Analytics Client authenticated successfully.")
        
    except Exception as e:
        print(f"An error occurred: {e}")
    
    #Authenticate Databricks Client and test the connection by listing the clusters
    try:
        databrickworkspace = authenticate_databricks_client()
        print(f"Databricks Client authenticated successfully. Connected to: {databrickworkspace.config.host}")

        clusters = list(databrickworkspace.clusters.list())
        if clusters:
            for cluster in clusters:
                print(f"Cluster Name: {cluster.cluster_name}, State: {cluster.state}")
        else:
            print("No clusters found in the Databricks workspace.")
    
    except Exception as e:
        print(f"An error occurred: {e}")

    #Load data from Databricks and return the first few rows
    try:
        catalog_name = "workspace"  
        schema_name = "default"    
        table_name = "job_descriptions"      
        
        df = load_data_from_databricks(catalog_name, schema_name, table_name)
        print("Data loaded successfully from Databricks. Here are the first few rows:")
        print(df.head())
    
    except Exception as e:
        print(f"An error occurred: {e}")


if __name__ == "__main__":
    main()
