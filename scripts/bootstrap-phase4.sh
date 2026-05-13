#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PHASE4_DIR="${ROOT_DIR}/bootstrap/phase-4"
DEV_DIR="${ROOT_DIR}/terraform/environments/dev"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing: $1" >&2; exit 1; }
}
require_cmd kubectl
require_cmd helm

echo "Validating Phase 4 secret manifests..."
required=( "${PHASE4_DIR}/manifests/secrets/pg-airflow-app-secret.yaml" )
for f in "${required[@]}"; do
  if [[ ! -f "${f}" ]]; then
    echo "Missing ${f}. Run scripts/prepare-phase4-secrets.sh first." >&2
    exit 1
  fi
done

# --- resolve Spark image reference -------------------------------------------
# Priority:
#   1. ${SPARK_IMAGE} env var (full reference)
#   2. ${REGISTRY}/dataplatform/spark-iceberg:${TAG:-3.5.0}
#   3. terraform output ecr_registry_url -> ${REGISTRY}/dataplatform/spark-iceberg:3.5.0
NAME_PREFIX="${NAME_PREFIX:-dataplatform}"
TAG="${TAG:-3.5.0}"
if [[ -z "${SPARK_IMAGE:-}" ]]; then
  if [[ -z "${REGISTRY:-}" ]] && command -v terraform >/dev/null 2>&1 && [[ -d "${DEV_DIR}/.terraform" ]]; then
    REGISTRY="$(terraform -chdir="${DEV_DIR}" output -raw ecr_registry_url 2>/dev/null || true)"
  fi
  if [[ -n "${REGISTRY:-}" ]]; then
    SPARK_IMAGE="${REGISTRY}/${NAME_PREFIX}/spark-iceberg:${TAG}"
  fi
fi

if [[ -z "${SPARK_IMAGE:-}" ]]; then
  echo "WARNING: SPARK_IMAGE not resolved; SparkApplication CRDs will keep REPLACE_ME_REGISTRY token." >&2
  echo "         Set SPARK_IMAGE=... or run 'terraform apply' (Phase 9 ECR module) first." >&2
fi

echo "Adding Helm repositories..."
helm repo add spark-operator https://kubeflow.github.io/spark-operator >/dev/null 2>&1 || true
helm repo add apache-airflow https://airflow.apache.org >/dev/null 2>&1 || true
helm repo update >/dev/null

echo "Applying CNPG cluster for Airflow metadata..."
kubectl apply -f "${PHASE4_DIR}/manifests/secrets/pg-airflow-app-secret.yaml"
kubectl apply -f "${PHASE4_DIR}/manifests/postgres/cnpg-airflow-cluster.yaml"

echo "Waiting for pg-airflow Cluster to be Ready..."
kubectl wait cluster/pg-airflow -n platform-storage \
  --for=condition=Ready --timeout=15m || true

echo "Installing Spark Operator..."
helm upgrade --install spark-operator spark-operator/spark-operator \
  --namespace platform-compute --create-namespace \
  -f "${PHASE4_DIR}/helm/spark-operator-values.yaml" \
  --wait --timeout 10m

echo "Applying Spark RBAC (ServiceAccount + Role)..."
kubectl apply -f "${PHASE4_DIR}/manifests/spark-rbac/"

echo "Rendering & applying SparkApplication CRDs (image: ${SPARK_IMAGE:-<unresolved>})..."
RENDERED_DIR="${PHASE4_DIR}/manifests/spark-jobs/.rendered"
mkdir -p "${RENDERED_DIR}"
for f in "${PHASE4_DIR}/manifests/spark-jobs/"*.yaml; do
  out="${RENDERED_DIR}/$(basename "${f}")"
  if [[ -n "${SPARK_IMAGE:-}" ]]; then
    sed "s|REPLACE_ME_REGISTRY/dataplatform/spark-iceberg:3.5.0|${SPARK_IMAGE}|g" "${f}" > "${out}"
  else
    cp "${f}" "${out}"
  fi
done
kubectl apply -f "${RENDERED_DIR}/" || true

echo "Building airflow-dags ConfigMap from ./dags/ + rendered SparkApplication manifests..."
"${ROOT_DIR}/scripts/prepare-airflow-dags.sh"

echo "Installing Airflow (mounts airflow-dags ConfigMap at /opt/airflow/dags)..."
helm upgrade --install airflow apache-airflow/airflow \
  --namespace platform-orchestr --create-namespace \
  -f "${PHASE4_DIR}/helm/airflow-values.yaml" \
  --wait --timeout 20m

echo "Granting Airflow worker SA permission to manage SparkApplications in platform-compute..."
kubectl apply -f "${PHASE4_DIR}/manifests/spark-rbac/airflow-spark-rolebinding.yaml" || true

echo "Phase 4 bootstrap complete."
cat <<EOF
Next:
  kubectl -n platform-compute get pods,sparkapplications
  kubectl -n platform-orchestr port-forward svc/airflow-webserver 8081:8080
  # Login: admin / admin (change in airflow-values.yaml)
EOF
