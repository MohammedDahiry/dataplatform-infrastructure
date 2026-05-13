# Phase 6 Bootstrap (Cloudflare Zero Trust — exposure)

Per `Specifications_Doc_for_PFE.pdf` §7.

This phase exposes selected services (Airflow, Dremio, Grafana, NiFi, JupyterHub) to
authenticated users **without opening any inbound port** on the EKS cluster. Traffic
flows: user -> Cloudflare edge (Access policies) -> outbound `cloudflared` tunnel ->
Kubernetes Service.

## Components

- `cloudflare-operator` Helm release in `platform-security` (spec §2.2 — same namespace as cert-manager).
- `ClusterTunnel` CRD pointing at a Cloudflare Tunnel created in the dashboard (or via Terraform later).
- `TunnelBinding` examples for Airflow, Dremio, Grafana, NiFi.
- Cloudflare API token mounted via secret (gitignored, generated from `*.example.yaml`).

## Prerequisites

- Cloudflare account + zone (your domain) — free tier is fine.
- Cloudflare Tunnel created in the Zero Trust dashboard (note the **tunnel ID** + **tunnel token**).
- API token scoped to: `Account.Cloudflare Tunnel:Edit`, `Zone.DNS:Edit`.

## Deploy

**Recommended:** run the helper (writes secrets + patches `REPLACE_ME_*` in Helm / tunnel manifests):

```bash
chmod +x scripts/configure-cloudflare.sh scripts/bootstrap-phase6.sh
./scripts/configure-cloudflare.sh    # prompts for account ID, API token, tunnel UUID/secret, DNS zone
./scripts/bootstrap-phase6.sh
```

**Manual:** copy `*.example.yaml` → `*.yaml` under `manifests/secrets/`, edit placeholders, then run `./scripts/bootstrap-phase6.sh`. You must still replace `REPLACE_ME_*` in `helm/`, `cluster-tunnel/`, and `tunnel-bindings/` unless you use `configure-cloudflare.sh`.

The script:
1. Adds the Cloudflare Helm repo.
2. Installs the Cloudflare Operator into `platform-security`.
3. Applies the API token + tunnel credentials secrets.
4. Applies `ClusterTunnel` (one tunnel for the whole cluster).
5. Applies `TunnelBinding` examples — comment out the ones you don't have yet.

## After deploy

- Each `TunnelBinding` reconciles to a DNS record `*.dataplatform.<your-zone>` -> tunnel.
- Configure **Cloudflare Access** policies in the dashboard (GitHub SSO, IdP claims, device posture).
- Test: `https://airflow.dataplatform.<your-zone>` should prompt for SSO before reaching Airflow.