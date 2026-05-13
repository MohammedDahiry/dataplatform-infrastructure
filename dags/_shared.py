"""Shared helpers for the platform DAGs.

The SparkApplication CRDs are rendered to ``/opt/airflow/dags/spark/`` by the
``prepare-airflow-dags.sh`` helper (which copies the rendered manifests from
``bootstrap/phase-4/manifests/spark-jobs/.rendered/`` into the ConfigMap so Airflow
can read them locally without giving the worker pod write access to the cluster).
"""

from __future__ import annotations

from pathlib import Path

SPARK_MANIFEST_DIR = Path("/opt/airflow/dags/spark")

DEFAULT_NAMESPACE = "platform-compute"
KUBERNETES_CONN_ID = "kubernetes_default"


def manifest(name: str) -> str:
    """Return the on-disk path to a rendered SparkApplication manifest."""
    path = SPARK_MANIFEST_DIR / f"{name}.yaml"
    if not path.exists():
        raise FileNotFoundError(
            f"Spark manifest {path} missing; run scripts/prepare-airflow-dags.sh "
            "after scripts/bootstrap-phase4.sh to refresh the ConfigMap."
        )
    return str(path)
