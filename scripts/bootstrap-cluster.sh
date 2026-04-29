#!/usr/bin/env bash
set -euo pipefail

BOOTSTRAP_DIR="bootstrap"

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl not found in PATH" >&2
  exit 1
fi

if [ ! -d "${BOOTSTRAP_DIR}" ]; then
  echo "Missing ${BOOTSTRAP_DIR}/ directory" >&2
  exit 1
fi

echo "Applying bootstrap manifests from ${BOOTSTRAP_DIR}/"
kubectl apply -f "${BOOTSTRAP_DIR}/" --recursive

echo "Bootstrap complete."
