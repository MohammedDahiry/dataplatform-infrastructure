#!/usr/bin/env bash
# Teardown of the dev environment so AWS stops billing.
# Order matters: clean Kubernetes-managed AWS resources (LoadBalancers, EBS PVCs)
# BEFORE terraform destroy, otherwise the VPC/EKS destroy can hang or leak volumes.
#
# This script does NOT touch:
#   - terraform/bootstrap (state bucket, KMS, R2)
#   - any Cloudflare R2 bucket holding the Terraform state
#
# Usage:
#   ./scripts/teardown-infra.sh --auto-approve
#   ./scripts/teardown-infra.sh --skip-k8s              # only terraform destroy
#   ./scripts/teardown-infra.sh --keep-namespaces       # do not delete platform-* namespaces
#   ./scripts/teardown-infra.sh --help

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEV_DIR="${ROOT_DIR}/terraform/environments/dev"

AUTO_APPROVE=false
SKIP_K8S=false
KEEP_NAMESPACES=false

usage() {
  cat <<'EOF'
teardown-infra.sh

Destroys the dev landing zone (EKS, VPC, NAT, etc.) so AWS stops billing.

Options:
  --auto-approve        Pass -auto-approve to terraform destroy.
  --skip-k8s            Skip Kubernetes cleanup (use only if cluster is already gone).
  --keep-namespaces     Do not delete platform-* namespaces (PVCs may leak EBS volumes).
  --help                Show this help.

What it does (in order):
  1. Uninstall Helm releases that may have created LoadBalancers / Ingresses.
  2. Delete all PVCs in platform-* namespaces (releases EBS volumes).
  3. Delete platform namespaces (unless --keep-namespaces).
  4. terraform destroy in terraform/environments/dev.

What it does NOT touch:
  - terraform/bootstrap (state bucket, KMS keys, R2 bucket).
  - Cloudflare R2 contents.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --auto-approve) AUTO_APPROVE=true ;;
    --skip-k8s) SKIP_K8S=true ;;
    --keep-namespaces) KEEP_NAMESPACES=true ;;
    --help|-h) usage; exit 0 ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
  shift
done

require_cmd() {
  local cmd="$1"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "Missing command: ${cmd}" >&2
    exit 1
  fi
}

confirm() {
  if [[ "${AUTO_APPROVE}" == true ]]; then
    return 0
  fi
  read -r -p "$1 [y/N]: " ans
  [[ "${ans}" == "y" || "${ans}" == "Y" ]]
}

echo "==> Teardown start"
echo "    root: ${ROOT_DIR}"

require_cmd terraform

if ! confirm "This will DESTROY the dev EKS cluster, VPC, NAT and all Kubernetes data. Continue?"; then
  echo "Aborted."
  exit 1
fi

if [[ "${SKIP_K8S}" != true ]]; then
  if command -v kubectl >/dev/null 2>&1 && kubectl cluster-info >/dev/null 2>&1; then
    echo "==> Kubernetes cluster is reachable; cleaning workloads first"

    if command -v helm >/dev/null 2>&1; then
      echo "    Uninstalling Helm releases (best-effort)..."
      # Phase 3
      helm uninstall strimzi-operator -n platform-ingestion >/dev/null 2>&1 || true
      # Phase 2
      helm uninstall hive-metastore-db -n platform-metastore >/dev/null 2>&1 || true
      helm uninstall cnpg -n platform-storage >/dev/null 2>&1 || true
      helm uninstall minio-operator -n platform-storage >/dev/null 2>&1 || true
      helm uninstall cert-manager -n platform-security >/dev/null 2>&1 || true
      # legacy install (pre-spec-alignment): cert-manager used to live in its own ns.
      helm uninstall cert-manager -n cert-manager >/dev/null 2>&1 || true
    else
      echo "    helm not found; skipping Helm release uninstall"
    fi

    echo "    Deleting LoadBalancer/Ingress services to release ELBs..."
    kubectl get svc --all-namespaces -o json 2>/dev/null \
      | python3 -c '
import json, sys
data = json.load(sys.stdin)
for item in data.get("items", []):
    if item.get("spec", {}).get("type") == "LoadBalancer":
        ns = item["metadata"]["namespace"]
        name = item["metadata"]["name"]
        print(f"{ns} {name}")
' 2>/dev/null \
      | while read -r ns name; do
          [[ -n "${ns}" && -n "${name}" ]] || continue
          echo "      kubectl -n ${ns} delete svc ${name}"
          kubectl -n "${ns}" delete svc "${name}" --wait=false >/dev/null 2>&1 || true
        done

    echo "    Deleting PVCs in platform-* namespaces (releases EBS volumes)..."
    for ns in $(kubectl get ns -o name 2>/dev/null | sed 's|^namespace/||' | grep -E '^(platform-|cert-manager$)'); do
      kubectl -n "${ns}" delete pvc --all --wait=false >/dev/null 2>&1 || true
    done

    if [[ "${KEEP_NAMESPACES}" != true ]]; then
      echo "    Deleting platform namespaces..."
      for ns in platform-ingestion platform-metastore platform-storage platform-security cert-manager; do
        kubectl delete ns "${ns}" --wait=false >/dev/null 2>&1 || true
      done
    fi

    # Give AWS a few seconds to start ELB / EBS deletion before terraform destroys the VPC.
    echo "    Waiting 30s for AWS to release ELBs and EBS volumes..."
    sleep 30
  else
    echo "==> Cluster unreachable or kubectl missing; skipping K8s cleanup"
  fi
fi

if [[ ! -d "${DEV_DIR}" ]]; then
  echo "Missing ${DEV_DIR}" >&2
  exit 1
fi

if [[ ! -f "${DEV_DIR}/.terraform/terraform.tfstate" && ! -d "${DEV_DIR}/.terraform" ]]; then
  echo "==> Terraform not initialized in ${DEV_DIR}"
  echo "    Run scripts/tf-init-local.sh terraform/environments/dev first."
  exit 1
fi

echo "==> terraform destroy (Phase 1 infra)"
if [[ "${AUTO_APPROVE}" == true ]]; then
  terraform -chdir="${DEV_DIR}" destroy -input=false -auto-approve
else
  terraform -chdir="${DEV_DIR}" destroy -input=false
fi

echo "==> Done"
cat <<'EOF'

Cost-saving teardown complete.

Bring it back later with:
    ./scripts/fasttrack-infra.sh --auto-approve --with-phase2
or step-by-step (see docs/IMPLEMENTATION_ETAPES.md "Mode accéléré").

Reminder: terraform/bootstrap (state bucket, KMS, R2) was NOT touched.
EOF
