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
CERT_MANAGER_WAIT_TIMEOUT="${CERT_MANAGER_WAIT_TIMEOUT:-25m}"
CERT_MANAGER_REPLICAS="${CERT_MANAGER_REPLICAS:-1}"

echo "Installing cert-manager into platform-security (spec §2.2)..."
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace platform-security --create-namespace \
  --version "${CERT_MANAGER_CHART_VERSION}" \
  -f "${PHASE2_DIR}/helm/cert-manager-values.yaml" \
  --set replicaCount="${CERT_MANAGER_REPLICAS}" \
  --set cainjector.replicaCount="${CERT_MANAGER_REPLICAS}" \
  --set webhook.replicaCount="${CERT_MANAGER_REPLICAS}" \
  --wait --timeout "${CERT_MANAGER_WAIT_TIMEOUT}"

echo "Ensuring cert-manager deployments are not scaled to zero..."
kubectl -n platform-security scale deployment \
  cert-manager cert-manager-cainjector cert-manager-webhook \
  --replicas="${CERT_MANAGER_REPLICAS}" || true

echo "Waiting for cert-manager deployments..."
kubectl wait --for=condition=Available deployment \
  -l app.kubernetes.io/instance=cert-manager \
  -n platform-security --timeout=600s

echo "Applying RBAC and secrets..."
kubectl apply -f "${PHASE2_DIR}/manifests/rbac/"
kubectl apply -f "${PHASE2_DIR}/manifests/secrets/minio-admin-secret.yaml"
kubectl apply -f "${PHASE2_DIR}/manifests/secrets/pg-source-app-secret.yaml"
kubectl apply -f "${PHASE2_DIR}/manifests/secrets/pg-hms-app-secret.yaml"
kubectl apply -f "${PHASE2_DIR}/manifests/secrets/hive-db-secret.yaml"

echo "Installing MinIO Operator..."
helm upgrade --install minio-operator minio-operator/operator \
  --namespace platform-storage --create-namespace \
  -f "${PHASE2_DIR}/helm/minio-operator-values.yaml" \
  --wait --timeout 5m

echo "Waiting for MinIO Operator to be ready..."
kubectl -n platform-storage wait --for=condition=Available \
  deployment/minio-operator --timeout=300s

echo "Applying MinIO tenant..."
kubectl apply -f "${PHASE2_DIR}/manifests/minio/"

echo "Installing CloudNativePG operator..."
helm upgrade --install cnpg cnpg/cloudnative-pg \
  --namespace platform-storage --create-namespace \
  -f "${PHASE2_DIR}/helm/cnpg-values.yaml" \
  --wait --timeout 5m

echo "Waiting for CNPG webhook endpoints to be ready..."
kubectl -n platform-storage wait --for=condition=Available \
  deployment/cnpg-cloudnative-pg --timeout=300s
# Wait until the webhook service actually has endpoints (not just the deployment available)
for i in $(seq 1 30); do
  if kubectl -n platform-storage get endpoints cnpg-webhook-service \
       -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null | grep -q .; then
    echo "  CNPG webhook endpoints are ready."
    break
  fi
  echo "  Waiting for cnpg-webhook-service endpoints... ($i/30)"
  sleep 5
done

echo "Applying PostgreSQL clusters..."
kubectl apply -f "${PHASE2_DIR}/manifests/postgres/"

echo "Installing Hive metastore PostgreSQL..."
helm upgrade --install hive-metastore-db bitnami/postgresql \
  --namespace platform-metastore --create-namespace \
  -f "${PHASE2_DIR}/helm/hive-postgresql-values.yaml" \
  --wait --timeout 5m

echo "Applying Hive metastore config..."
kubectl apply -f "${PHASE2_DIR}/manifests/hive/"

echo "Phase 2 bootstrap complete."