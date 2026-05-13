"""File-based ingestion (CSV / XLSX) -> Iceberg Bronze.

Reads files from ``s3a://landing/files/`` and writes them as Iceberg tables in
the Bronze layer. Use for the spec §4.3 file ingestion pattern.

Args (CLI flags):
    --source-path     s3a://... glob to read.
    --target-table    Iceberg fully-qualified name (e.g. lakehouse.bronze.raw_files).
    --file-format     xlsx | csv (default: xlsx).
"""

from __future__ import annotations

import argparse
import os

from pyspark.sql import SparkSession


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-path", required=True)
    parser.add_argument("--target-table", required=True)
    parser.add_argument("--file-format", default="xlsx", choices=["xlsx", "csv"])
    return parser.parse_args()


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
        SparkSession.builder.appName("file-to-iceberg-ingestion")
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


def main() -> None:
    args = parse_args()
    spark = build_spark()
    spark.sql("CREATE NAMESPACE IF NOT EXISTS lakehouse.bronze")

    if args.file_format == "xlsx":
        df = (
            spark.read.format("com.crealytics.spark.excel")
            .option("header", "true")
            .option("inferSchema", "true")
            .load(args.source_path)
        )
    else:
        df = (
            spark.read.option("header", "true")
            .option("inferSchema", "true")
            .csv(args.source_path)
        )

    (
        df.writeTo(args.target_table)
        .tableProperty("write.format.default", "parquet")
        .tableProperty("write.parquet.compression-codec", "zstd")
        .createOrReplace()
    )


if __name__ == "__main__":
    main()
