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


def random_df_split(df, numrows:int):
    '''
    Returns a random sample of the DataFrame with the specified number of rows.
    '''
    if numrows > len(df):
        raise ValueError("numrows must be less than or equal to the number of rows in the DataFrame.")
    return df.sample(n=numrows, random_state=42)


def analyze_sentiment(azure_client, df, text_column, batch_size=10):
    '''
    Analyzes sentiment for text in a DataFrame column using Azure Text Analytics.
    
    Parameters:
    azure_client (TextAnalyticsClient): Authenticated Azure Text Analytics client.
    df (pd.DataFrame): DataFrame containing text to analyze.
    text_column (str): Name of the column containing text to analyze.
    batch_size (int): Number of documents per API call (max 10 for Azure).
    
    Returns:
    pd.DataFrame: Original DataFrame with sentiment_score and sentiment_label columns added.
    '''
    sentiment_scores = []
    sentiment_labels = []
    
    # Get text data, handle NaN values
    texts = df[text_column].fillna("").astype(str).tolist()
    
    # Process in batches (Azure limit is 10 documents per request)
    for i in range(0, len(texts), batch_size):
        batch = texts[i:i + batch_size]
        
        # Skip empty batches
        if not any(batch):
            sentiment_scores.extend([None] * len(batch))
            sentiment_labels.extend([None] * len(batch))
            continue
        
        try:
            response = azure_client.analyze_sentiment(batch)
            
            for doc in response:
                if doc.is_error:
                    print(f"Error analyzing document: {doc.error.message}")
                    sentiment_scores.append(None)
                    sentiment_labels.append(None)
                else:
                    # Get confidence score for the detected sentiment
                    confidence = max(
                        doc.confidence_scores.positive,
                        doc.confidence_scores.neutral,
                        doc.confidence_scores.negative
                    )
                    sentiment_scores.append(confidence)
                    sentiment_labels.append(doc.sentiment.capitalize())  # 'Positive', 'Neutral', 'Negative'
                    
        except Exception as e:
            print(f"Error processing batch {i // batch_size + 1}: {e}")
            sentiment_scores.extend([None] * len(batch))
            sentiment_labels.extend([None] * len(batch))
    
    # Add results to DataFrame
    df = df.copy()
    df['sentiment_score'] = sentiment_scores
    df['sentiment_label'] = sentiment_labels
    
    return df


def extract_key_phrases(azure_client, df, text_column, batch_size=10):
    '''
    Extracts key phrases from text in a DataFrame column using Azure Text Analytics.
    
    Parameters:
    azure_client (TextAnalyticsClient): Authenticated Azure Text Analytics client.
    df (pd.DataFrame): DataFrame containing text to analyze.
    text_column (str): Name of the column containing text to analyze.
    batch_size (int): Number of documents per API call (max 10 for Azure).
    
    Returns:
    pd.DataFrame: DataFrame with job_id and extracted key phrases (one row per phrase).
    '''
    results = []
    
    # Get text data and job IDs
    texts = df[text_column].fillna("").astype(str).tolist()
    job_ids = df['Job Id'].tolist()
    
    # Process in batches
    for i in range(0, len(texts), batch_size):
        batch_texts = texts[i:i + batch_size]
        batch_ids = job_ids[i:i + batch_size]
        
        try:
            response = azure_client.extract_key_phrases(batch_texts)
            
            for doc, job_id in zip(response, batch_ids):
                if doc.is_error:
                    print(f"Error extracting key phrases for job {job_id}: {doc.error.message}")
                    continue
                    
                for phrase in doc.key_phrases:
                    results.append({
                        'job_id': job_id,
                        'phrase': phrase,
                        'source_field': text_column
                    })
                    
        except Exception as e:
            print(f"Error processing batch {i // batch_size + 1}: {e}")
    
    return pd.DataFrame(results)


def recognize_entities(azure_client, df, text_column, batch_size=10):
    '''
    Recognizes named entities from text in a DataFrame column using Azure Text Analytics.
    
    Parameters:
    azure_client (TextAnalyticsClient): Authenticated Azure Text Analytics client.
    df (pd.DataFrame): DataFrame containing text to analyze.
    text_column (str): Name of the column containing text to analyze.
    batch_size (int): Number of documents per API call (max 10 for Azure).
    
    Returns:
    pd.DataFrame: DataFrame with job_id and recognized entities (one row per entity).
    '''
    results = []
    
    # Get text data and job IDs
    texts = df[text_column].fillna("").astype(str).tolist()
    job_ids = df['Job Id'].tolist()
    
    # Process in batches
    for i in range(0, len(texts), batch_size):
        batch_texts = texts[i:i + batch_size]
        batch_ids = job_ids[i:i + batch_size]
        
        try:
            response = azure_client.recognize_entities(batch_texts)
            
            for doc, job_id in zip(response, batch_ids):
                if doc.is_error:
                    print(f"Error recognizing entities for job {job_id}: {doc.error.message}")
                    continue
                    
                for entity in doc.entities:
                    results.append({
                        'job_id': job_id,
                        'entity_name': entity.text,
                        'entity_type': entity.category,
                        'confidence': entity.confidence_score
                    })
                    
        except Exception as e:
            print(f"Error processing batch {i // batch_size + 1}: {e}")
    
    return pd.DataFrame(results)


def run_all_nlp_analysis(azure_client, df, text_column='Job Description'):
    '''
    Runs all NLP analyses (sentiment, key phrases, entities) on a DataFrame.
    
    Parameters:
    azure_client (TextAnalyticsClient): Authenticated Azure Text Analytics client.
    df (pd.DataFrame): DataFrame containing text to analyze.
    text_column (str): Name of the column containing text to analyze.
    
    Returns:
    tuple: (df_with_sentiment, df_key_phrases, df_entities)
    '''
    print(f"Running NLP analysis on {len(df)} documents...")
    print(f"Text column: {text_column}")
    print("-" * 50)
    
    # 1. Sentiment Analysis
    print("\n[1/3] Analyzing sentiment...")
    df_with_sentiment = analyze_sentiment(azure_client, df, text_column)
    print(f"Sentiment distribution:")
    print(df_with_sentiment['sentiment_label'].value_counts())
    
    # 2. Key Phrase Extraction
    print("\n[2/3] Extracting key phrases...")
    df_key_phrases = extract_key_phrases(azure_client, df, text_column)
    print(f"Extracted {len(df_key_phrases)} key phrases from {df_key_phrases['job_id'].nunique()} jobs.")
    
    # 3. Entity Recognition
    print("\n[3/3] Recognizing entities...")
    df_entities = recognize_entities(azure_client, df, text_column)
    print(f"Recognized {len(df_entities)} entities from {df_entities['job_id'].nunique()} jobs.")
    print(f"Entity types found: {df_entities['entity_type'].unique().tolist()}")
    
    print("-" * 50)
    print("NLP analysis complete!")
    
    return df_with_sentiment, df_key_phrases, df_entities


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

        if df.empty:
            print("The DataFrame is empty. Please check the table name and ensure it contains data.")
        else:
            print("Data loaded successfully from Databricks.")
    
    except Exception as e:
        print(f"An error occurred: {e}")
    
    #Randomly sample 100 rows from the DataFrame
    try:
        df_sample = random_df_split(df, 100)
        print("Random sample of 100 rows:")
        print(df_sample.head())
    except Exception as e:
        print(f"An error occurred while sampling: {e}")


if __name__ == "__main__":
    main()
