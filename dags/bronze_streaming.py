"""Bronze streaming pipeline.

Submits the long-running ``bronze-iceberg-writer`` SparkApplication once.
Re-running the DAG no-ops thanks to the SparkApplication idempotent name.
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
    dag_id="bronze_streaming",
    description="Stream Kafka cdc.* into Iceberg Bronze (long-running)",
    start_date=datetime(2026, 1, 1),
    schedule="@once",
    catchup=False,
    tags=["bronze", "streaming", "iceberg"],
) as dag:
    submit = SparkKubernetesOperator(
        task_id="submit_bronze_writer",
        namespace=DEFAULT_NAMESPACE,
        application_file=manifest("bronze-iceberg-writer"),
        kubernetes_conn_id=KUBERNETES_CONN_ID,
        do_xcom_push=False,
    )

    monitor = SparkKubernetesSensor(
        task_id="monitor_bronze_writer",
        namespace=DEFAULT_NAMESPACE,
        application_name="bronze-iceberg-writer",
        kubernetes_conn_id=KUBERNETES_CONN_ID,
        attach_log=True,
    )

    submit >> monitor
