#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PHASE7_DIR="${ROOT_DIR}/bootstrap/phase-7"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing: $1" >&2; exit 1; }
}
require_cmd kubectl
require_cmd helm
require_cmd openssl
require_cmd python3

WORKDIR="$(mktemp -d)"
trap 'rm -rf "${WORKDIR}"' EXIT

GRAFANA_ADMIN_PASSWORD="$(openssl rand -base64 24)"
OPENOBSERVE_ADMIN_PASSWORD="$(openssl rand -base64 24)"

python3 - "${PHASE7_DIR}" "${WORKDIR}" "${GRAFANA_ADMIN_PASSWORD}" "${OPENOBSERVE_ADMIN_PASSWORD}" <<'PY'
import pathlib
import sys

phase7, workdir, grafana_pw, oo_pw = sys.argv[1:5]
base = pathlib.Path(phase7)
out = pathlib.Path(workdir)

plan = [
    (
        "helm/kube-prometheus-stack-values.yaml",
        "kube-prometheus-stack-values.yaml",
        [("REPLACE_ME_GRAFANA_ADMIN_PASSWORD", grafana_pw)],
    ),
    (
        "helm/openobserve-values.yaml",
        "openobserve-values.yaml",
        [("REPLACE_ME_OPENOBSERVE_ADMIN_PASSWORD", oo_pw)],
    ),
    (
        "helm/fluent-bit-values.yaml",
        "fluent-bit-values.yaml",
        [("REPLACE_ME_OPENOBSERVE_ADMIN_PASSWORD", oo_pw)],
    ),
]

for rel_src, out_name, replacements in plan:
    text = (base / rel_src).read_text(encoding="utf-8")
    for ph, val in replacements:
        if ph not in text:
            raise SystemExit(f"placeholder {ph!r} not found in {rel_src}")
        text = text.replace(ph, val)
    (out / out_name).write_text(text, encoding="utf-8")
PY

echo "Adding Helm repos..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
helm repo add openobserve         https://charts.openobserve.ai >/dev/null 2>&1 || true
helm repo add fluent              https://fluent.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update >/dev/null

echo "Installing kube-prometheus-stack..."
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --namespace platform-monitoring --create-namespace \
  -f "${WORKDIR}/kube-prometheus-stack-values.yaml" \
  --wait --timeout 20m

echo "Installing OpenObserve..."
helm upgrade --install openobserve openobserve/openobserve-standalone \
  --namespace platform-logging --create-namespace \
  -f "${WORKDIR}/openobserve-values.yaml" \
  --wait --timeout 15m

echo "Installing Fluent Bit DaemonSet..."
helm upgrade --install fluent-bit fluent/fluent-bit \
  --namespace platform-logging \
  -f "${WORKDIR}/fluent-bit-values.yaml" \
  --wait --timeout 10m

echo "Applying ServiceMonitor / PodMonitor CRDs..."
kubectl apply -f "${PHASE7_DIR}/manifests/servicemonitors/" || true

echo "Phase 7 bootstrap complete."
cat <<EOF

=== Passwords (shown once; not saved to a file) ===
Grafana:     user admin  /  ${GRAFANA_ADMIN_PASSWORD}
OpenObserve: user admin@dataplatform.local  /  ${OPENOBSERVE_ADMIN_PASSWORD}
(Fluent Bit uses the same OpenObserve password for HTTP basic auth to the OO API.)

Next:
  kubectl -n platform-monitoring port-forward svc/monitoring-grafana 3000:80
  kubectl -n platform-logging port-forward svc/openobserve 5080:5080
EOF
