#!/usr/bin/env bash
# Generate gitignored Phase 4 secrets from *.example.yaml (currently: pg-airflow).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SECRETS_DIR="${ROOT_DIR}/bootstrap/phase-4/manifests/secrets"

FORCE=false
if [[ "${1:-}" == "--force" ]]; then
  FORCE=true
fi

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing: $1" >&2; exit 1; }
}
require_cmd openssl

generate_password() {
  openssl rand -base64 24 | tr -d '\n+/=' | cut -c1-24
}

shopt -s nullglob
for example in "${SECRETS_DIR}"/*.example.yaml; do
  target="${example%.example.yaml}.yaml"
  if [[ -f "${target}" && "${FORCE}" != true ]]; then
    echo "skip ${target} (exists; --force to overwrite)"
    continue
  fi
  pw="$(generate_password)"
  sed "s|REPLACE_ME_STRONG_PASSWORD|${pw}|g" "${example}" > "${target}"
  echo "wrote ${target}"
done
