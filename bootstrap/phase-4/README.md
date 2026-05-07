# Phase 4 Bootstrap (Compute — Spark Operator + Airflow + dbt)

Per `Specifications_Doc_for_PFE.pdf` §3.5, §3.6, §6.1.

This phase deploys the **transformation and orchestration layer** that turns
Bronze (raw Iceberg) into Silver (cleaned) and Gold (BI-ready) datasets.

## Components

- **Kubeflow Spark Operator** in `platform-compute`.
- Sample `SparkApplication` CRDs that read MinIO via S3A and write Iceberg tables registered in Hive Metastore.
- **Apache Airflow** (Helm chart) in `platform-orchestr`, using `KubernetesExecutor` and external CNPG metadata DB.
- **dbt-spark** project skeleton (`dbt/`) with example silver/gold models. Runs as a Spark job triggered by Airflow.

## Prerequisites

- Phase 2 complete (cert-manager, MinIO Tenant Ready, CNPG `pg-airflow` Ready, Hive Metastore reachable on `9083`).
- Phase 3 complete (Kafka topics exist) — only required for streaming Spark jobs.
- `platform-compute` and `platform-orchestr` namespaces with quotas (Phase 1).

## Deploy

```bash
chmod +x scripts/bootstrap-phase4.sh
./scripts/bootstrap-phase4.sh
```

The script:
1. Adds Helm repos (`spark-operator`, `apache-airflow`).
2. Creates `pg-airflow` CNPG cluster (Airflow metadata) in `platform-storage`.
3. Generates secrets (`prepare-phase4-secrets.sh`) — gitignored.
4. Installs Spark Operator into `platform-compute`.
5. Applies `SparkApplication` examples (`bronze-iceberg-writer`, `file-to-iceberg`).
6. Installs Airflow into `platform-orchestr`.
7. Optionally applies the example DAG ConfigMap so the GitSync sidecar can pick it up.

## dbt project

`dbt/` is a starting point for `dbt-spark` against the lakehouse Hive Metastore.
Build the dbt-spark image (`Dockerfile`), push to ECR, then trigger via Airflow
`SparkSubmitOperator` or as a `SparkApplication` referencing the same image.