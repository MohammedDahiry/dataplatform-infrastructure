# Airflow DAGs

Reference DAGs for the Cloud Data Platform medallion pipeline.

These DAGs are loaded into Airflow via a Kubernetes ConfigMap (no separate Git
repo required for the soutenance / MVP). For a production setup, switch the
Airflow Helm chart to `dags.gitSync.enabled: true` and push these files to a
dedicated `dataplatform-airflow-dags` repository.

## DAGs

| DAG id | Trigger | What it does |
|--------|---------|--------------|
| `bronze_streaming` | `@once` | Submits the streaming `bronze-iceberg-writer` SparkApplication (Kafka → Iceberg Bronze). |
| `bronze_files_daily` | `@daily` | Submits `file-to-iceberg-ingestion` for `s3a://landing/files/*.xlsx`. |
| `silver_gold_dbt` | `@hourly` | Runs `dbt run` via a `dbt-run` SparkApplication using the same `spark-iceberg` image. |

All operators use `SparkKubernetesOperator` from `apache-airflow-providers-cncf-kubernetes`,
applying YAML templates from `bootstrap/phase-4/manifests/spark-jobs/.rendered/` (created
by `scripts/bootstrap-phase4.sh`).

## How DAGs reach Airflow

`scripts/prepare-airflow-dags.sh` generates a `airflow-dags` ConfigMap in
`platform-orchestr` from this folder. The Airflow Helm chart mounts it at
`/opt/airflow/dags` (see `bootstrap/phase-4/helm/airflow-values.yaml`).

Update flow:

```bash
# Edit dags/*.py
./scripts/prepare-airflow-dags.sh           # refreshes the ConfigMap
# Airflow scheduler picks up changes within ~30s (DagBag refresh).
```