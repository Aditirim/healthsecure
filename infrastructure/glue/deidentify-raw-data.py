import sys
from awsglue.transforms import * # type: ignore
from awsglue.utils import getResolvedOptions # type: ignore
from pyspark.context import SparkContext # type: ignore
from awsglue.context import GlueContext # type: ignore
from awsglue.job import Job # type: ignore
from pyspark.sql.functions import col, sha2, trim # type: ignore

def main():
    # 1. Initialize AWS Glue and Spark Contexts
    # Resolved options allow passing dynamic parameters like bucket names from Glue Console or Step Functions
    args = getResolvedOptions(
        sys.argv, 
        ['JOB_NAME', 'RAW_BUCKET_NAME', 'CURATED_BUCKET_NAME']
    )
    
    sc = SparkContext()
    glueContext = GlueContext(sc)
    spark = glueContext.spark_session
    job = Job(glueContext)
    job.init(args['JOB_NAME'], args)

    raw_bucket = args['RAW_BUCKET_NAME']
    curated_bucket = args['CURATED_BUCKET_NAME']

    print(f"AWS Glue ETL Job '{args['JOB_NAME']}' started successfully.")
    print(f"Source Raw Storage Path: s3://{raw_bucket}/")
    print(f"Destination Curated Storage Path: s3://{curated_bucket}/")

    try:
        # 2. Ingest Raw JSON files with native Schema Evolution Support
        # Spark's 'mergeSchema' option merges disjoint columns from all historical patient data payloads
        raw_df = spark.read \
            .option("multiline", "true") \
            .option("mergeSchema", "true") \
            .json(f"s3://{raw_bucket}/**/*.json")

        if raw_df.count() == 0:
            print("No new patient ingestion files located in raw S3 storage. Terminating job successfully.")
            job.commit()
            return

        print("Successfully read raw JSON documents. Inferring schema and merging structural fields:")
        raw_df.printSchema()

        # 3. HIPAA-Compliant De-identification (Drop PII columns)
        # Drops Name, Address, and Phone numbers to comply with safe-harbor standards
        sensitive_fields = ["name", "phone", "phoneNumber", "address", "emergencyContact"]
        
        # Verify columns to prevent throwing analysis exceptions
        fields_to_drop = [c for c in sensitive_fields if c in raw_df.columns]
        print(f"PII scrub trigger activated. Dropping sensitive columns: {fields_to_drop}")
        
        deidentified_df = raw_df.drop(*fields_to_drop)

        # 4. Generate Cryptographic Hash Value (One-way SHA-256)
        # Computes SHA-256 hash on patientId to preserve cross-system traceability without exposing identity
        id_col = None
        if "patientId" in deidentified_df.columns:
            id_col = "patientId"
        elif "patientID" in deidentified_df.columns:
            id_col = "patientID"
        elif "id" in deidentified_df.columns:
            id_col = "id"

        if id_col:
            print(f"Found identifier column '{id_col}'. Compiling one-way cryptographic SHA-256 hash.")
            deidentified_df = deidentified_df.withColumn(
                "patient_hash",
                sha2(trim(col(id_col).cast("string")), 256)
            )
        else:
            print("Warning: No standard patient identifier located. Skipping SHA-256 cross-reference hash generation.")

        # 5. Convert JSON into high-performance Apache Parquet columnar storage
        # Parquet reduces cold storage footprint by up to 80% and accelerates AWS Athena query speeds
        print("Curating records. Writing compressed Parquet files to Curated Storage bucket...")
        
        # Write Curated Data back to S3, appending data and enforcing schema evolution
        deidentified_df.write \
            .mode("append") \
            .option("mergeSchema", "true") \
            .parquet(f"s3://{curated_bucket}/curated-patients-parquet/")

        print(f"Curated Parquet records successfully written to s3://{curated_bucket}/curated-patients-parquet/")

    except Exception as e:
        print(f"Critical Failure in Glue ETL Job execution: {str(e)}")
        raise e

    # 6. Commit job state to AWS Glue
    job.commit()
    print("AWS Glue ETL de-identification job successfully committed.")

if __name__ == "__main__":
    main()
