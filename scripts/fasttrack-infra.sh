#!/usr/bin/env bash
# Fast-track infra deployment for WSL/local execution.
# Deploys Phase 1 end-to-end, then optionally Phase 2 and Phase 3.
#
# Usage:
#   ./scripts/fasttrack-infra.sh --auto-approve --with-phase2
#   ./scripts/fasttrack-infra.sh --auto-approve --with-phase2 --with-phase3
#   ./scripts/fasttrack-infra.sh --help

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEV_DIR="${ROOT_DIR}/terraform/environments/dev"

WITH_PHASE2=false
WITH_PHASE3=false
WITH_PHASE4=false
WITH_PHASE5=false
WITH_PHASE6=false
WITH_PHASE7=false
WITH_PHASE10=false
AUTO_APPROVE=false
SKIP_TERRAFORM=false
FORCE_REGEN_PHASE2_SECRETS=false

usage() {
  cat <<'EOF'
fasttrack-infra.sh

Options:
  --with-phase2                 Run Phase 2 (cert-manager, MinIO, CNPG, Hive).
  --with-phase3                 Run Phase 3 (Kafka, Connect, NiFi).
  --with-phase4                 Run Phase 4 (Spark Operator, Airflow, dbt).
  --with-phase5                 Run Phase 5 (Dremio).
  --with-phase6                 Run Phase 6 (Cloudflare Tunnel + Operator).
  --with-phase7                 Run Phase 7 (Prometheus, Grafana, Fluent Bit, OpenObserve).
  --with-phase10                Run Phase 10 (ArgoCD, optional).
  --with-all                    Phases 2..7 in order (10 stays opt-in).
  --auto-approve                Pass -auto-approve to terraform apply.
  --skip-terraform              Skip Terraform apply (run only K8s/bootstrap phases).
  --force-regenerate-secrets    Regenerate Phase 2 / Phase 4 secrets with --force.
  --help                        Show this help.

Required env vars for terraform backend init:
  TF_STATE_BUCKET, CF_ACCOUNT_ID, CF_R2_ACCESS_KEY_ID, CF_R2_SECRET_ACCESS_KEY

Recommended env var:
  AWS_PROFILE
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --with-phase2) WITH_PHASE2=true ;;
    --with-phase3) WITH_PHASE3=true; WITH_PHASE2=true ;;
    --with-phase4) WITH_PHASE4=true; WITH_PHASE2=true ;;
    --with-phase5) WITH_PHASE5=true; WITH_PHASE2=true ;;
    --with-phase6) WITH_PHASE6=true ;;
    --with-phase7) WITH_PHASE7=true ;;
    --with-phase10) WITH_PHASE10=true ;;
    --with-all) WITH_PHASE2=true; WITH_PHASE3=true; WITH_PHASE4=true; WITH_PHASE5=true; WITH_PHASE6=true; WITH_PHASE7=true ;;
    --auto-approve) AUTO_APPROVE=true ;;
    --skip-terraform) SKIP_TERRAFORM=true ;;
    --force-regenerate-secrets) FORCE_REGEN_PHASE2_SECRETS=true ;;
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

echo "==> Fast-track infra start"
echo "    root: ${ROOT_DIR}"

require_cmd aws
require_cmd terraform
require_cmd kubectl

if [[ "${WITH_PHASE2}" == true || "${WITH_PHASE3}" == true ]]; then
  require_cmd helm
  require_cmd openssl
fi

if [[ ! -f "${DEV_DIR}/terraform.tfvars" ]]; then
  echo "Missing ${DEV_DIR}/terraform.tfvars"
  echo "Copy terraform.tfvars.example and adapt values first."
  exit 1
fi

if [[ "${SKIP_TERRAFORM}" != true ]]; then
  : "${TF_STATE_BUCKET:?Set TF_STATE_BUCKET}"
  : "${CF_ACCOUNT_ID:?Set CF_ACCOUNT_ID}"
  : "${CF_R2_ACCESS_KEY_ID:?Set CF_R2_ACCESS_KEY_ID}"
  : "${CF_R2_SECRET_ACCESS_KEY:?Set CF_R2_SECRET_ACCESS_KEY}"

  echo "==> AWS identity check"
  aws sts get-caller-identity >/dev/null

  echo "==> Terraform backend init (R2)"
  "${ROOT_DIR}/scripts/tf-init-local.sh" terraform/environments/dev

  echo "==> Terraform plan (Phase 1 infra)"
  terraform -chdir="${DEV_DIR}" plan -input=false

  echo "==> Terraform apply (Phase 1 infra)"
  if [[ "${AUTO_APPROVE}" == true ]]; then
    terraform -chdir="${DEV_DIR}" apply -input=false -auto-approve
  else
    terraform -chdir="${DEV_DIR}" apply -input=false
  fi
fi

echo "==> Configure kubeconfig from terraform output"
KUBECONFIG_COMMAND="$(terraform -chdir="${DEV_DIR}" output -raw kubeconfig_command)"
if [[ -z "${KUBECONFIG_COMMAND}" ]]; then
  echo "kubeconfig_command output is empty. Check terraform apply status." >&2
  exit 1
fi
echo "    running: ${KUBECONFIG_COMMAND}"
eval "${KUBECONFIG_COMMAND}"

echo "==> Verify cluster connectivity"
kubectl get nodes

echo "==> Apply Phase 1 bootstrap manifests"
cd "${ROOT_DIR}"
./scripts/bootstrap-cluster.sh

if [[ "${WITH_PHASE2}" == true ]]; then
  echo "==> Generate Phase 2 secrets"
  if [[ "${FORCE_REGEN_PHASE2_SECRETS}" == true ]]; then
    ./scripts/prepare-phase2-secrets.sh --force
  else
    ./scripts/prepare-phase2-secrets.sh
  fi

  echo "==> Run Phase 2 bootstrap"
  ./scripts/bootstrap-phase2.sh
fi

if [[ "${WITH_PHASE3}" == true ]]; then
  echo "==> Phase 3 (Kafka + NiFi). Default variant: dev (1 broker + 1 ZK)."
  echo "    Override with KAFKA_VARIANT=prod for the 3+3 replicated cluster."
  ./scripts/bootstrap-phase3.sh
fi

if [[ "${WITH_PHASE4}" == true ]]; then
  echo "==> Phase 4 (Spark + Airflow + dbt)"
  if [[ "${FORCE_REGEN_PHASE2_SECRETS}" == true ]]; then
    ./scripts/prepare-phase4-secrets.sh --force
  else
    ./scripts/prepare-phase4-secrets.sh
  fi
  ./scripts/bootstrap-phase4.sh
fi

if [[ "${WITH_PHASE5}" == true ]]; then
  echo "==> Phase 5 (Dremio)"
  ./scripts/bootstrap-phase5.sh
fi

if [[ "${WITH_PHASE6}" == true ]]; then
  echo "==> Phase 6 (Cloudflare Tunnel) — secrets must be filled manually first"
  ./scripts/bootstrap-phase6.sh
fi

if [[ "${WITH_PHASE7}" == true ]]; then
  echo "==> Phase 7 (Observability)"
  ./scripts/bootstrap-phase7.sh
fi

if [[ "${WITH_PHASE10}" == true ]]; then
  echo "==> Phase 10 (ArgoCD)"
  ./scripts/bootstrap-phase10.sh
fi

echo "==> Done"
echo "Next: validate workloads, then move to data engineering tasks."
