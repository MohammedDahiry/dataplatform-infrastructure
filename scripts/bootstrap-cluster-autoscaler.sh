#!/usr/bin/env bash
# Install the Kubernetes Cluster Autoscaler so the compute-ng node group can
# grow from desired=1 to max=4 on demand (e.g. when Phase 4+5+7 run together).
#
# Prerequisites:
#   - terraform apply has created the cluster_autoscaler IRSA role
#   - kubeconfig points at the dev cluster
#   - helm is installed
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${ROOT_DIR}/terraform/environments/dev"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing: $1" >&2; exit 1; }
}
require_cmd helm
require_cmd kubectl
require_cmd terraform
require_cmd jq

echo "==> Reading IRSA role ARN from Terraform output..."
ROLE_ARN="$(terraform -chdir="${TF_DIR}" output -json irsa_role_arns | jq -r '.cluster_autoscaler')"
if [[ -z "${ROLE_ARN}" || "${ROLE_ARN}" == "null" ]]; then
  echo "ERROR: cluster_autoscaler IRSA role ARN not found. Run terraform apply first." >&2
  exit 1
fi

echo "    -> ${ROLE_ARN}"

VALUES_FILE="${ROOT_DIR}/bootstrap/phase-1/helm/cluster-autoscaler-values.yaml"
RENDERED="$(mktemp)"
trap 'rm -f "${RENDERED}"' EXIT
sed "s|REPLACE_ME_CLUSTER_AUTOSCALER_ROLE_ARN|${ROLE_ARN}|g" "${VALUES_FILE}" > "${RENDERED}"

echo "==> Adding autoscaler Helm repo..."
helm repo add autoscaler https://kubernetes.github.io/autoscaler >/dev/null 2>&1 || true
helm repo update autoscaler >/dev/null

echo "==> Installing cluster-autoscaler in kube-system..."
helm upgrade --install cluster-autoscaler autoscaler/cluster-autoscaler \
  --namespace kube-system \
  -f "${RENDERED}" \
  --wait --timeout 5m

echo "==> Done. Verify with: kubectl -n kube-system get deploy cluster-autoscaler"
