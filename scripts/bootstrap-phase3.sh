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
helm repo add strimzi https://strimzi.io/charts/ >/dev/null
helm repo update >/dev/null

echo "Installing Strimzi operator..."
helm upgrade --install strimzi-operator strimzi/strimzi-kafka-operator \
  --namespace platform-ingestion --create-namespace

echo "Applying Kafka cluster..."
kubectl apply -f "${PHASE3_DIR}/manifests/kafka/"

echo "Applying NiFi baseline..."
kubectl apply -f "${PHASE3_DIR}/manifests/nifi/"

echo "Phase 3 bootstrap complete."
