#!/usr/bin/env bash
# Generates Phase 2 Kubernetes secrets from *.example.yaml templates using random values.
# Generated *.yaml files are gitignored — commit only the examples.
#
# Usage:
#   ./scripts/prepare-phase2-secrets.sh           # skip if target *.yaml already exists
#   ./scripts/prepare-phase2-secrets.sh --force # overwrite existing *.yaml

set -euo pipefail

FORCE=false
if [[ "${1:-}" == "--force" ]]; then
  FORCE=true
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SECRETS_DIR="${ROOT_DIR}/bootstrap/phase-2/manifests/secrets"

rand_hex() {
  openssl rand -hex "${1:?}"
}

substitute_file() {
  local src="$1"
  local dst="$2"
  shift 2
  local tmp
  tmp="$(mktemp)"
  cp "${src}" "${tmp}"

  while [[ "$#" -ge 2 ]]; do
    local placeholder="$1"
    local value="$2"
    shift 2
    sed "s|${placeholder}|${value}|g" "${tmp}" >"${tmp}.out"
    mv "${tmp}.out" "${tmp}"
  done

  mv "${tmp}" "${dst}"
}

echo "Secrets directory: ${SECRETS_DIR}"

declare -a PAIRS=(
  "minio-admin-secret.example.yaml|minio-admin-secret.yaml"
  "pg-source-app-secret.example.yaml|pg-source-app-secret.yaml"
  "pg-hms-app-secret.example.yaml|pg-hms-app-secret.yaml"
  "hive-db-secret.example.yaml|hive-db-secret.yaml"
)

for pair in "${PAIRS[@]}"; do
  IFS='|' read -r src_name dst_name <<<"${pair}"
  src="${SECRETS_DIR}/${src_name}"
  dst="${SECRETS_DIR}/${dst_name}"

  if [[ ! -f "${src}" ]]; then
    echo "Missing template: ${src}" >&2
    exit 1
  fi

  if [[ -f "${dst}" ]] && [[ "${FORCE}" != true ]]; then
    echo "Keep existing (use --force to overwrite): ${dst}"
    continue
  fi

  echo "Write ${dst_name}"

  case "${dst_name}" in
    minio-admin-secret.yaml)
      substitute_file "${src}" "${dst}" \
        REPLACE_MINIO_ACCESS_KEY "$(rand_hex 12)" \
        REPLACE_MINIO_SECRET_KEY "$(rand_hex 32)"
      ;;
    pg-source-app-secret.yaml)
      substitute_file "${src}" "${dst}" \
        REPLACE_PG_SOURCE_PASSWORD "$(rand_hex 24)"
      ;;
    pg-hms-app-secret.yaml)
      substitute_file "${src}" "${dst}" \
        REPLACE_PG_HMS_PASSWORD "$(rand_hex 24)"
      ;;
    hive-db-secret.yaml)
      substitute_file "${src}" "${dst}" \
        REPLACE_HIVE_DB_PASSWORD "$(rand_hex 24)"
      ;;
    *)
      echo "Unhandled: ${dst_name}" >&2
      exit 1
      ;;
  esac
done

echo "Done. Review files under ${SECRETS_DIR} (*.yaml, not *.example.yaml)."
echo "Then run: ./scripts/bootstrap-phase2.sh"
