#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PHASE7_DIR="${ROOT_DIR}/bootstrap/phase-7"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing: $1" >&2; exit 1; }
}
require_cmd kubectl
require_cmd helm

echo "Adding Helm repos..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
helm repo add openobserve         https://charts.openobserve.ai >/dev/null 2>&1 || true
helm repo add fluent              https://fluent.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update >/dev/null

echo "Installing kube-prometheus-stack..."
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --namespace platform-monitoring --create-namespace \
  -f "${PHASE7_DIR}/helm/kube-prometheus-stack-values.yaml" \
  --wait --timeout 20m

echo "Installing OpenObserve..."
helm upgrade --install openobserve openobserve/openobserve-standalone \
  --namespace platform-logging --create-namespace \
  -f "${PHASE7_DIR}/helm/openobserve-values.yaml" \
  --wait --timeout 15m

echo "Installing Fluent Bit DaemonSet..."
helm upgrade --install fluent-bit fluent/fluent-bit \
  --namespace platform-logging \
  -f "${PHASE7_DIR}/helm/fluent-bit-values.yaml" \
  --wait --timeout 10m

echo "Applying ServiceMonitor / PodMonitor CRDs..."
kubectl apply -f "${PHASE7_DIR}/manifests/servicemonitors/" || true

echo "Phase 7 bootstrap complete."
cat <<EOF
Next:
  kubectl -n platform-monitoring port-forward svc/monitoring-grafana 3000:80
  kubectl -n platform-logging port-forward svc/openobserve 5080:5080
EOF
