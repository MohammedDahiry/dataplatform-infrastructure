#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PHASE3_DIR="${ROOT_DIR}/bootstrap/phase-3"

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl not found in PATH" >&2
  exit 1
fi

if ! command -v helm >/dev/null 2>&1; then
  echo "helm not found in PATH" >&2
  exit 1
fi

echo "Adding Strimzi Helm repository..."
helm repo add strimzi https://strimzi.io/charts/ >/dev/null 2>&1 || true
helm repo update >/dev/null

echo "Installing Strimzi operator..."
helm upgrade --install strimzi-operator strimzi/strimzi-kafka-operator \
  --namespace platform-ingestion --create-namespace \
  --wait --timeout 10m

echo "Waiting for Strimzi cluster operator..."
if kubectl get deployment strimzi-cluster-operator -n platform-ingestion >/dev/null 2>&1; then
  kubectl rollout status deployment/strimzi-cluster-operator -n platform-ingestion --timeout=300s
fi

KAFKA_VARIANT="${KAFKA_VARIANT:-dev}"
case "${KAFKA_VARIANT}" in
  dev)  KAFKA_FILE="${PHASE3_DIR}/manifests/kafka/strimzi-kafka-dev.yaml" ;;
  prod) KAFKA_FILE="${PHASE3_DIR}/manifests/kafka/strimzi-kafka.yaml" ;;
  *) echo "Unknown KAFKA_VARIANT=${KAFKA_VARIANT}" >&2; exit 1 ;;
esac

echo "Applying Kafka cluster (variant: ${KAFKA_VARIANT}) -> ${KAFKA_FILE}..."
kubectl apply -f "${KAFKA_FILE}"

echo "Waiting for Kafka cluster Ready..."
kubectl wait kafka/platform-kafka -n platform-ingestion \
  --for=condition=Ready --timeout=15m || true

echo "Applying Kafka topics (medallion bronze + CDC)..."
kubectl apply -f "${PHASE3_DIR}/manifests/kafka/topics.yaml"

echo "Applying Kafka Connect + Debezium connector (CDC pg-source -> cdc.pg.*)..."
kubectl apply -f "${PHASE3_DIR}/manifests/kafka/kafka-connect.yaml"

echo "Applying NiFi baseline..."
kubectl apply -f "${PHASE3_DIR}/manifests/nifi/"

echo "Phase 3 bootstrap complete."
cat <<EOF
Next:
  kubectl -n platform-ingestion get kafka,kafkatopic,kafkaconnect,kafkaconnector
  kubectl -n platform-ingestion port-forward svc/nifi 8080:8080
EOF
