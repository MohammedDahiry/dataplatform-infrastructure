"""Daily file ingestion pipeline.

Submits ``file-to-iceberg-ingestion`` SparkApplication every day at 02:00 UTC,
reading ``s3a://landing/files/*.xlsx`` and writing to ``lakehouse.bronze.raw_files``.
"""

from __future__ import annotations

from datetime import datetime

from airflow import DAG
from airflow.providers.cncf.kubernetes.operators.spark_kubernetes import (
    SparkKubernetesOperator,
)
from airflow.providers.cncf.kubernetes.sensors.spark_kubernetes import (
    SparkKubernetesSensor,
)

from _shared import DEFAULT_NAMESPACE, KUBERNETES_CONN_ID, manifest

with DAG(
    dag_id="bronze_files_daily",
    description="Daily XLSX/CSV ingestion from MinIO landing -> Iceberg Bronze",
    start_date=datetime(2026, 1, 1),
    schedule="0 2 * * *",
    catchup=False,
    tags=["bronze", "batch", "files"],
) as dag:
    submit = SparkKubernetesOperator(
        task_id="submit_file_ingestion",
        namespace=DEFAULT_NAMESPACE,
        application_file=manifest("file-to-iceberg-ingestion"),
        kubernetes_conn_id=KUBERNETES_CONN_ID,
        do_xcom_push=False,
    )

    monitor = SparkKubernetesSensor(
        task_id="monitor_file_ingestion",
        namespace=DEFAULT_NAMESPACE,
        application_name="file-to-iceberg-ingestion",
        kubernetes_conn_id=KUBERNETES_CONN_ID,
        attach_log=True,
    )

    submit >> monitor
