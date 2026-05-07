#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PHASE6_DIR="${ROOT_DIR}/bootstrap/phase-6"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing: $1" >&2; exit 1; }
}
require_cmd kubectl
require_cmd helm

echo "Validating Phase 6 secrets..."
required=(
  "${PHASE6_DIR}/manifests/secrets/cloudflare-api-token.yaml"
  "${PHASE6_DIR}/manifests/secrets/cloudflare-tunnel-credentials.yaml"
)
for f in "${required[@]}"; do
  if [[ ! -f "${f}" ]]; then
    echo "Missing ${f}." >&2
    echo "Copy *.example.yaml, fill credentials, and re-run." >&2
    exit 1
  fi
done

echo "Adding Cloudflare Helm repo..."
helm repo add cloudflare https://cloudflare.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update >/dev/null

echo "Applying Cloudflare secrets..."
kubectl apply -f "${PHASE6_DIR}/manifests/secrets/cloudflare-api-token.yaml"
kubectl apply -f "${PHASE6_DIR}/manifests/secrets/cloudflare-tunnel-credentials.yaml"

echo "Installing Cloudflare Operator into platform-security (spec §2.2)..."
helm upgrade --install cloudflare-operator cloudflare/cloudflare-operator \
  --namespace platform-security \
  -f "${PHASE6_DIR}/helm/cloudflare-operator-values.yaml" \
  --wait --timeout 10m

echo "Applying ClusterTunnel..."
kubectl apply -f "${PHASE6_DIR}/manifests/cluster-tunnel/cluster-tunnel.yaml"

echo "Applying TunnelBinding examples (edit hostnames first)..."
kubectl apply -f "${PHASE6_DIR}/manifests/tunnel-bindings/" || true

echo "Phase 6 bootstrap complete."
cat <<EOF
Next:
  - In Cloudflare Zero Trust dashboard, create Access applications for each FQDN
    (airflow./dremio./grafana./nifi.dataplatform.<your-zone>).
  - Configure GitHub SSO + Access policies (group / email / device posture).
EOF
