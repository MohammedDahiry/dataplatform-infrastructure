"""dbt-spark transformations Bronze -> Silver -> Gold.

Submits the ``dbt-run`` SparkApplication every hour. The same `spark-iceberg`
image runs ``dbt run --target dev`` from the embedded project at /opt/dbt.
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
    dag_id="silver_gold_dbt",
    description="dbt run: Bronze -> Silver -> Gold (Iceberg via Spark)",
    start_date=datetime(2026, 1, 1),
    schedule="@hourly",
    catchup=False,
    tags=["silver", "gold", "dbt", "iceberg"],
) as dag:
    submit = SparkKubernetesOperator(
        task_id="submit_dbt_run",
        namespace=DEFAULT_NAMESPACE,
        application_file=manifest("dbt-run"),
        kubernetes_conn_id=KUBERNETES_CONN_ID,
        do_xcom_push=False,
    )

    monitor = SparkKubernetesSensor(
        task_id="monitor_dbt_run",
        namespace=DEFAULT_NAMESPACE,
        application_name="dbt-run",
        kubernetes_conn_id=KUBERNETES_CONN_ID,
        attach_log=True,
    )

    submit >> monitor
