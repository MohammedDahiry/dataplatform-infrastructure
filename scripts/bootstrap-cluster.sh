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

# Phase 1 only — do not apply phase-2/phase-3 (operators, DBs, Kafka) from this script.
echo "Applying Phase 1 bootstrap manifests from ${BOOTSTRAP_DIR}/"
for sub in namespaces storage-classes resource-quotas network-policies; do
  dir="${BOOTSTRAP_DIR}/${sub}"
  if [ -d "${dir}" ]; then
    echo "  -> ${dir}/"
    kubectl apply -f "${dir}/" --recursive
  fi
done

echo "Phase 1 bootstrap complete. For MinIO/CNPG/Hive use scripts/bootstrap-phase2.sh; for Kafka/NiFi use scripts/bootstrap-phase3.sh."
