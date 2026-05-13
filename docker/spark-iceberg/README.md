# spark-iceberg image

Container image used by every Spark job in this platform (Phase 4 SparkApplications,
dbt-spark runs triggered from Airflow).

## What's inside

- Base: `spark:3.5.0-scala2.12-java17-python3-ubuntu` (Docker Official Image `library/spark`; not `apache/spark`).
- Spec-aligned jars in `$SPARK_HOME/jars/`:
  - `iceberg-spark-runtime-3.5_2.12-1.4.2`
  - `hadoop-aws-3.3.4`
  - `aws-java-sdk-bundle-1.12.262`
  - `spark-excel_2.12-3.5.0_0.20.3`
- Python deps (`requirements.txt`): `pyspark`, `pandas`, `pyarrow`, `boto3`, `openpyxl`, `dbt-core`, `dbt-spark`.
- Embedded jobs at **`/opt/jobs/`** (`bronze_writer.py`, `file_ingestion.py`).
- dbt project at **`/opt/dbt/`** (mirror of `bootstrap/phase-4/dbt/`).

Because PySpark scripts and the dbt project ship inside the image, SparkApplication
CRDs reference them via `local:///opt/jobs/...` — **no upload to MinIO required**.

## Build & push

Pre-requisites: `docker`, `aws` CLI, an authenticated AWS profile, and the ECR
repository created (`module "ecr"` in `terraform/environments/dev`).

```bash
# After 'terraform apply' (Phase 1 + ECR module), push the image:
./scripts/build-spark-image.sh

# Override the tag if needed
TAG=3.5.0-rc1 ./scripts/build-spark-image.sh

# Override the registry (e.g. if you use a local Harbor or another account)
REGISTRY=harbor.local:5000 ./scripts/build-spark-image.sh
```

The script:
1. Resolves the ECR registry from `terraform output ecr_registry_url` (or env var).
2. Logs in with `aws ecr get-login-password`.
3. `docker build -t <REGISTRY>/<NAME_PREFIX>/spark-iceberg:<TAG> .`
4. Pushes the image.

## Use the image in SparkApplication CRDs

The YAMLs ship with a placeholder:

```yaml
image: REPLACE_ME_REGISTRY/dataplatform/spark-iceberg:3.5.0
```

`scripts/bootstrap-phase4.sh` substitutes that token at apply time:

```bash
# Auto-detects ECR registry from terraform output
./scripts/bootstrap-phase4.sh

# Or pass an explicit image
SPARK_IMAGE=395249042632.dkr.ecr.us-east-1.amazonaws.com/dataplatform/spark-iceberg:3.5.0 \
  ./scripts/bootstrap-phase4.sh
```

The rendered manifests land in `bootstrap/phase-4/manifests/spark-jobs/.rendered/`
(gitignored) before `kubectl apply`.

## Run a manual smoke test

```bash
docker run --rm -it --entrypoint /opt/spark/bin/spark-submit \
  REPLACE_ME_REGISTRY/dataplatform/spark-iceberg:3.5.0 --version
```

## Update / rebuild flow

1. Edit `jobs/*.py` or `requirements.txt`.
2. Bump `TAG` (e.g. `TAG=3.5.0-1`).
3. `./scripts/build-spark-image.sh`.
4. `SPARK_IMAGE=<new image> ./scripts/bootstrap-phase4.sh` to roll out.