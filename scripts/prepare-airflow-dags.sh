#!/usr/bin/env bash
# Build the airflow-dags ConfigMap from dags/*.py + the rendered SparkApplication
# manifests in bootstrap/phase-4/manifests/spark-jobs/.rendered/.
#
# Run after scripts/bootstrap-phase4.sh (which renders the SparkApplication YAMLs).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DAGS_DIR="${ROOT_DIR}/dags"
RENDERED_DIR="${ROOT_DIR}/bootstrap/phase-4/manifests/spark-jobs/.rendered"
NAMESPACE="${AIRFLOW_NAMESPACE:-platform-orchestr}"
CONFIGMAP="${AIRFLOW_DAGS_CONFIGMAP:-airflow-dags}"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing: $1" >&2; exit 1; }
}
require_cmd kubectl

if [[ ! -d "${DAGS_DIR}" ]]; then
  echo "Missing ${DAGS_DIR}" >&2
  exit 1
fi

if [[ ! -d "${RENDERED_DIR}" || -z "$(ls -A "${RENDERED_DIR}" 2>/dev/null)" ]]; then
  echo "WARNING: ${RENDERED_DIR} is empty. Run scripts/bootstrap-phase4.sh first" >&2
  echo "         so SparkApplication YAMLs are rendered with the real image." >&2
fi

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT

cp "${DAGS_DIR}"/*.py "${WORK_DIR}/"
if compgen -G "${RENDERED_DIR}/*.yaml" > /dev/null; then
  cp "${RENDERED_DIR}"/*.yaml "${WORK_DIR}/"
fi

echo "Generating ConfigMap ${NAMESPACE}/${CONFIGMAP} from $(ls "${WORK_DIR}" | wc -l) DAG files + spark templates..."
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f - >/dev/null

# Rebuild the configmap: --dry-run + apply gives idempotent updates.
kubectl create configmap "${CONFIGMAP}" \
  --namespace "${NAMESPACE}" \
  --from-file="${WORK_DIR}" \
  --dry-run=client -o yaml \
  | kubectl apply -f -

echo "ConfigMap ${NAMESPACE}/${CONFIGMAP} updated."
echo "Airflow scheduler picks up changes within ~30s (DagBag refresh)."
