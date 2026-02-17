'''
Docstring for python.python_databricks_to_azure.main
'''
import os
import databricks.sdk as databricks
from dotenv import load_dotenv
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
    
    except Exception as e:
        print(f"An error occurred: {e}")



if __name__ == "__main__":
    main()