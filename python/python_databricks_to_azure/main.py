'''
Docstring for python.python_databricks_to_azure.main
'''
import os
from dotenv import load_dotenv
from azure.ai.textanalytics import TextAnalyticsClient
from azure.core.credentials import AzureKeyCredential

def authenticate_client():
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


def main():
    '''
    Main function.
    '''
    try:
        client = authenticate_client()
        print("Client authenticated successfully.")
        
    except Exception as e:
        print(f"An error occurred: {e}")


if __name__ == "__main__":
    main()
