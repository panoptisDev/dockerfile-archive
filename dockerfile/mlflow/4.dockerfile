FROM python:3.7

WORKDIR /app

# Install mlflow and packages requied to interact with PostgreSQL and MinIO
RUN pip install mlflow psycopg2 boto3
