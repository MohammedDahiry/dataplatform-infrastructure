#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PHASE4_DIR="${ROOT_DIR}/bootstrap/phase-4"

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

echo "Applying example SparkApplication CRDs (image references must be edited)..."
kubectl apply -f "${PHASE4_DIR}/manifests/spark-jobs/" || true

echo "Installing Airflow..."
helm upgrade --install airflow apache-airflow/airflow \
  --namespace platform-orchestr --create-namespace \
  -f "${PHASE4_DIR}/helm/airflow-values.yaml" \
  --wait --timeout 20m

echo "Phase 4 bootstrap complete."
cat <<EOF
Next:
  kubectl -n platform-compute get pods,sparkapplications
  kubectl -n platform-orchestr port-forward svc/airflow-webserver 8081:8080
  # Login: admin / admin (change in airflow-values.yaml)
EOF
