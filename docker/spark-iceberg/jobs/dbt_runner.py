"""dbt runner driver.

Spark Operator requires a Spark application as the main entry, but we want to
trigger dbt-spark commands inside the same image. This driver:

1. Initialises a SparkSession with the Iceberg + S3A configuration.
2. Shells out to ``dbt`` with the CLI args passed via the SparkApplication
   ``spec.arguments`` (e.g. ``run --project-dir=/opt/dbt``).
3. Returns the dbt exit code as the Spark job exit code so the Spark Operator
   reflects the real status.
"""

from __future__ import annotations

import os
import subprocess
import sys

from pyspark.sql import SparkSession


def build_spark() -> SparkSession:
    minio_endpoint = os.environ.get(
        "S3A_ENDPOINT",
        "http://lakehouse-tenant-hl.platform-storage.svc.cluster.local:9000",
    )
    hms_uri = os.environ.get(
        "HMS_URI",
        "thrift://hive-metastore.platform-metastore.svc.cluster.local:9083",
    )
    return (
        SparkSession.builder.appName("dbt-runner")
        .config(
            "spark.sql.extensions",
            "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions",
        )
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


def main() -> int:
    spark = build_spark()
    try:
        spark.sparkContext.setLogLevel("WARN")
        cmd = ["dbt", *sys.argv[1:]]
        print(f"[dbt_runner] running: {' '.join(cmd)}", flush=True)
        return subprocess.call(cmd)
    finally:
        spark.stop()


if __name__ == "__main__":
    sys.exit(main())
