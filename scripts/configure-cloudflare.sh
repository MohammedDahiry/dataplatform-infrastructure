#!/usr/bin/env bash
# Render the Phase 6 Cloudflare manifests with your real account/tunnel/domain.
#
# Reads:
#   $CF_ACCOUNT_ID           Cloudflare account ID
#   $CF_ACCOUNT_NAME         Cloudflare account display name (used by the operator)
#   $CF_API_TOKEN            Cloudflare API token (Account.Cloudflare Tunnel:Edit, Zone.DNS:Edit)
#   $CF_TUNNEL_ID            UUID of the tunnel created in Zero Trust dashboard
#   $CF_TUNNEL_SECRET        Base64 tunnel secret (`TunnelSecret` in credentials.json)
#   $CF_DOMAIN               Zone (e.g. dahiry.com) — services are exposed at <svc>.dataplatform.<CF_DOMAIN>
#
# Falls back to interactive prompts when a variable is missing.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PHASE6_DIR="${ROOT_DIR}/bootstrap/phase-6"

prompt() {
  local var="$1"; local label="$2"; local secret="${3:-false}"
  if [[ -z "${!var:-}" ]]; then
    if [[ "${secret}" == true ]]; then
      read -r -s -p "${label}: " value
      echo
    else
      read -r -p "${label}: " value
    fi
    printf -v "${var}" '%s' "${value}"
  fi
}

prompt CF_ACCOUNT_ID    "Cloudflare account ID"
prompt CF_ACCOUNT_NAME  "Cloudflare account NAME (display)"
prompt CF_API_TOKEN     "Cloudflare API token" true
prompt CF_TUNNEL_ID     "Tunnel UUID"
prompt CF_TUNNEL_SECRET "Tunnel secret (base64)" true
prompt CF_DOMAIN        "Public DNS zone (e.g. dahiry.com)"

echo "==> Writing secrets..."
cat > "${PHASE6_DIR}/manifests/secrets/cloudflare-api-token.yaml" <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: cloudflare-api-token
  namespace: platform-security
type: Opaque
stringData:
  token: ${CF_API_TOKEN}
EOF

cat > "${PHASE6_DIR}/manifests/secrets/cloudflare-tunnel-credentials.yaml" <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: cloudflare-tunnel-credentials
  namespace: platform-security
type: Opaque
stringData:
  credentials.json: |
    {
      "AccountTag": "${CF_ACCOUNT_ID}",
      "TunnelSecret": "${CF_TUNNEL_SECRET}",
      "TunnelID": "${CF_TUNNEL_ID}"
    }
EOF

echo "==> Patching Helm values + ClusterTunnel + TunnelBindings..."
sed -i \
  -e "s|REPLACE_ME_CF_ACCOUNT_ID|${CF_ACCOUNT_ID}|g" \
  "${PHASE6_DIR}/helm/cloudflare-operator-values.yaml"

sed -i \
  -e "s|REPLACE_ME_CF_ACCOUNT_NAME|${CF_ACCOUNT_NAME}|g" \
  -e "s|REPLACE_ME_ZONE_EXAMPLE_COM|${CF_DOMAIN}|g" \
  "${PHASE6_DIR}/manifests/cluster-tunnel/cluster-tunnel.yaml"

for f in "${PHASE6_DIR}/manifests/tunnel-bindings/"*.yaml; do
  sed -i "s|REPLACE_ME_ZONE_EXAMPLE_COM|${CF_DOMAIN}|g" "${f}"
done

echo "==> Cloudflare configuration written. Public hostnames:"
for f in "${PHASE6_DIR}/manifests/tunnel-bindings/"*.yaml; do
  grep -E '^\s+fqdn:' "${f}" | awk '{print "    "$2}'
done
echo
echo "Next: ./scripts/bootstrap-phase6.sh"
