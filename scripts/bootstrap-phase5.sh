#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PHASE5_DIR="${ROOT_DIR}/bootstrap/phase-5"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing: $1" >&2; exit 1; }
}
require_cmd kubectl
require_cmd helm
require_cmd python3

echo "Adding Dremio Helm repository..."
helm repo add dremio https://dremio.github.io/dremio-cloud-tools >/dev/null 2>&1 || true
helm repo update >/dev/null

echo "Resolving MinIO credentials from platform-storage (Phase 2 secret minio-admin-secret)..."
if ! kubectl -n platform-storage get secret minio-admin-secret >/dev/null 2>&1; then
  echo "Secret minio-admin-secret not found. Run Phase 2 first (prepare-phase2-secrets.sh + bootstrap-phase2.sh)." >&2
  exit 1
fi

ACCESS_KEY="$(kubectl -n platform-storage get secret minio-admin-secret -o jsonpath='{.data.accesskey}' | base64 -d)"
SECRET_KEY="$(kubectl -n platform-storage get secret minio-admin-secret -o jsonpath='{.data.secretkey}' | base64 -d)"
if [[ -z "${ACCESS_KEY}" || -z "${SECRET_KEY}" ]]; then
  echo "Could not read accesskey/secretkey from minio-admin-secret." >&2
  exit 1
fi

VALUES_RENDERED="$(mktemp)"
trap 'rm -f "${VALUES_RENDERED}"' EXIT

python3 - "${PHASE5_DIR}/helm/dremio-values.yaml" "${ACCESS_KEY}" "${SECRET_KEY}" "${VALUES_RENDERED}" <<'PY'
import pathlib
import sys

src_path, access_key, secret_key, out_path = sys.argv[1:5]
text = pathlib.Path(src_path).read_text(encoding="utf-8")
count = text.count("REPLACE_ME")
if count != 2:
    sys.exit(f"expected exactly 2 REPLACE_ME placeholders in dremio-values.yaml, found {count}")
text = text.replace("REPLACE_ME", access_key, 1)
text = text.replace("REPLACE_ME", secret_key, 1)
pathlib.Path(out_path).write_text(text, encoding="utf-8")
PY

echo "Installing Dremio into platform-serving..."
helm upgrade --install dremio dremio/dremio_v2 \
  --namespace platform-serving --create-namespace \
  -f "${VALUES_RENDERED}" \
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
