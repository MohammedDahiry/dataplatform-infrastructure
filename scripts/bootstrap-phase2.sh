#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PHASE2_DIR="${ROOT_DIR}/bootstrap/phase-2"

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl not found in PATH" >&2
  exit 1
fi

if ! command -v helm >/dev/null 2>&1; then
  echo "helm not found in PATH" >&2
  exit 1
fi

echo "Validating required secret manifests..."
required_secret_files=(
  "${PHASE2_DIR}/manifests/secrets/minio-admin-secret.yaml"
  "${PHASE2_DIR}/manifests/secrets/pg-source-app-secret.yaml"
  "${PHASE2_DIR}/manifests/secrets/pg-hms-app-secret.yaml"
  "${PHASE2_DIR}/manifests/secrets/hive-db-secret.yaml"
)

for f in "${required_secret_files[@]}"; do
  if [[ ! -f "${f}" ]]; then
    echo "Missing required file: ${f}" >&2
    echo "Create it from the corresponding *.example.yaml template first." >&2
    exit 1
  fi
done

echo "Adding Helm repositories..."
helm repo add jetstack https://charts.jetstack.io >/dev/null 2>&1 || true
helm repo add minio-operator https://operator.min.io >/dev/null
helm repo add cnpg https://cloudnative-pg.github.io/charts >/dev/null
helm repo add bitnami https://charts.bitnami.com/bitnami >/dev/null
helm repo update >/dev/null

CERT_MANAGER_CHART_VERSION="${CERT_MANAGER_CHART_VERSION:-v1.14.5}"

echo "Installing cert-manager (TLS prerequisite per spec Phase 2)..."
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --version "${CERT_MANAGER_CHART_VERSION}" \
  -f "${PHASE2_DIR}/helm/cert-manager-values.yaml" \
  --wait --timeout 10m

echo "Waiting for cert-manager deployments..."
kubectl wait --for=condition=Available deployment --all -n cert-manager --timeout=300s

echo "Applying RBAC and secrets..."
kubectl apply -f "${PHASE2_DIR}/manifests/rbac/"
kubectl apply -f "${PHASE2_DIR}/manifests/secrets/minio-admin-secret.yaml"
kubectl apply -f "${PHASE2_DIR}/manifests/secrets/pg-source-app-secret.yaml"
kubectl apply -f "${PHASE2_DIR}/manifests/secrets/pg-hms-app-secret.yaml"
kubectl apply -f "${PHASE2_DIR}/manifests/secrets/hive-db-secret.yaml"

echo "Installing MinIO Operator..."
helm upgrade --install minio-operator minio-operator/operator \
  --namespace platform-storage --create-namespace \
  -f "${PHASE2_DIR}/helm/minio-operator-values.yaml"

echo "Applying MinIO tenant..."
kubectl apply -f "${PHASE2_DIR}/manifests/minio/"

echo "Installing CloudNativePG operator..."
helm upgrade --install cnpg cnpg/cloudnative-pg \
  --namespace platform-storage --create-namespace \
  -f "${PHASE2_DIR}/helm/cnpg-values.yaml"

echo "Applying PostgreSQL clusters..."
kubectl apply -f "${PHASE2_DIR}/manifests/postgres/"

echo "Installing Hive metastore PostgreSQL..."
helm upgrade --install hive-metastore-db bitnami/postgresql \
  --namespace platform-metastore --create-namespace \
  -f "${PHASE2_DIR}/helm/hive-postgresql-values.yaml"

echo "Applying Hive metastore config..."
kubectl apply -f "${PHASE2_DIR}/manifests/hive/"

echo "Phase 2 bootstrap complete."
