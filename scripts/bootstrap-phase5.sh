#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PHASE5_DIR="${ROOT_DIR}/bootstrap/phase-5"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing: $1" >&2; exit 1; }
}
require_cmd kubectl
require_cmd helm

echo "Adding Dremio Helm repository..."
helm repo add dremio https://dremio.github.io/dremio-cloud-tools >/dev/null 2>&1 || true
helm repo update >/dev/null

echo "Installing Dremio into platform-serving..."
helm upgrade --install dremio dremio/dremio_v2 \
  --namespace platform-serving --create-namespace \
  -f "${PHASE5_DIR}/helm/dremio-values.yaml" \
  --wait --timeout 25m

echo "Waiting for Dremio coordinator..."
kubectl -n platform-serving rollout status statefulset/dremio-master --timeout=600s || true

echo "Phase 5 bootstrap complete."
cat <<EOF
Next:
  kubectl -n platform-serving port-forward svc/dremio-client 9047:9047
  # Open http://localhost:9047 -> create admin user
  # Then add the Hive source from manifests/dremio/source-hive.json
EOF
