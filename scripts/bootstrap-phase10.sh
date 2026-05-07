#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PHASE10_DIR="${ROOT_DIR}/bootstrap/phase-10"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing: $1" >&2; exit 1; }
}
require_cmd kubectl
require_cmd helm

echo "Adding ArgoCD Helm repo..."
helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
helm repo update >/dev/null

echo "Installing ArgoCD into platform-security..."
helm upgrade --install argocd argo/argo-cd \
  --namespace platform-security \
  -f "${PHASE10_DIR}/helm/argocd-values.yaml" \
  --wait --timeout 15m

echo "Applying AppProject + example Applications..."
kubectl apply -f "${PHASE10_DIR}/manifests/projects/" || true
kubectl apply -f "${PHASE10_DIR}/manifests/applications/" || true

echo "Phase 10 bootstrap complete."
cat <<EOF
Initial admin password:
  kubectl -n platform-security get secret argocd-initial-admin-secret \\
    -o jsonpath='{.data.password}' | base64 -d ; echo
Port-forward UI:
  kubectl -n platform-security port-forward svc/argocd-server 8443:443
EOF
