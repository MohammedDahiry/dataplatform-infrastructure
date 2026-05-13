"""Streaming Bronze writer.

Reads Debezium CDC events from Kafka topics ``cdc.pg.public.*`` produced by the
KafkaConnect deployment in Phase 3, lands them as raw Iceberg tables under
``lakehouse.bronze.*``. Schema is left as-is (Bronze keeps original fidelity).

Trigger: SparkApplication CRD (`bootstrap/phase-4/manifests/spark-jobs/bronze-iceberg-writer.yaml`).

Environment:
    MINIO_ACCESS_KEY, MINIO_SECRET_KEY  - injected from secret/minio-admin-secret
    KAFKA_BOOTSTRAP                     - default platform-kafka-kafka-bootstrap.platform-ingestion:9092
    HMS_URI                             - default thrift://hive-metastore.platform-metastore.svc.cluster.local:9083
"""

from __future__ import annotations

import os
import sys

from pyspark.sql import SparkSession
from pyspark.sql.functions import col, current_timestamp, expr


def build_spark() -> SparkSession:
    minio_endpoint = os.environ.get(
        "S3A_ENDPOINT",
        "http://lakehouse-tenant-hl.platform-storage.svc.cluster.local:9000",
    )
    hms_uri = os.environ.get(
        "HMS_URI",
        "thrift://hive-metastore.platform-metastore.svc.cluster.local:9083",
    )

    spark = (
        SparkSession.builder.appName("bronze-iceberg-writer")
        .config("spark.sql.extensions", "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions")
        .config("spark.sql.catalog.lakehouse", "org.apache.iceberg.spark.SparkCatalog")
        .config("spark.sql.catalog.lakehouse.type", "hive")
        .config("spark.sql.catalog.lakehouse.uri", hms_uri)
        .config("spark.sql.catalog.lakehouse.warehouse", "s3a://lakehouse/warehouse/")
        .config("spark.hadoop.fs.s3a.endpoint", minio_endpoint)
        .config("spark.hadoop.fs.s3a.path.style.access", "true")
        .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem")
        .config("spark.hadoop.fs.s3a.access.key", os.environ["MINIO_ACCESS_KEY"])
        .config("spark.hadoop.fs.s3a.secret.key", os.environ["MINIO_SECRET_KEY"])
        .getOrCreate()
    )
    spark.sparkContext.setLogLevel("WARN")
    return spark


def main(topic: str, target_table: str) -> None:
    spark = build_spark()

    bootstrap = os.environ.get(
        "KAFKA_BOOTSTRAP",
        "platform-kafka-kafka-bootstrap.platform-ingestion:9092",
    )

    spark.sql("CREATE NAMESPACE IF NOT EXISTS lakehouse.bronze")

    raw = (
        spark.readStream.format("kafka")
        .option("kafka.bootstrap.servers", bootstrap)
        .option("subscribe", topic)
        .option("startingOffsets", "earliest")
        .load()
    )

    bronze = raw.select(
        col("topic"),
        col("partition"),
        col("offset"),
        col("timestamp").alias("kafka_ts"),
        expr("CAST(key AS STRING)").alias("key"),
        expr("CAST(value AS STRING)").alias("value"),
        current_timestamp().alias("ingested_at"),
    )

    query = (
        bronze.writeStream.format("iceberg")
        .option("path", target_table)
        .option("checkpointLocation", f"s3a://lakehouse/_checkpoints/{target_table}")
        .outputMode("append")
        .trigger(processingTime="30 seconds")
        .start()
    )
    query.awaitTermination()


if __name__ == "__main__":
    if len(sys.argv) >= 3:
        topic_arg, table_arg = sys.argv[1], sys.argv[2]
    else:
        topic_arg = os.environ.get("KAFKA_TOPIC", "cdc.pg.public.agency_budget")
        table_arg = os.environ.get("ICEBERG_TABLE", "lakehouse.bronze.agency_budget_raw")

    main(topic_arg, table_arg)
