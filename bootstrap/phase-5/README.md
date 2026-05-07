# Phase 5 Bootstrap (Dremio Nautilus — query federation & BI)

Per `Specifications_Doc_for_PFE.pdf` §8.

This phase deploys the **virtualization / serving layer**:

- **Dremio Nautilus** in `platform-serving`, with split coordinator + executor pods
  for independent scaling.
- A pre-baked Hive Metastore source pointing at our `hive-metastore.platform-metastore:9083`
  + MinIO S3A endpoint (`bootstrap/phase-5/manifests/dremio/source-hive.json`).
- Dremio is the entry point for **Power BI** (Apache Arrow Flight or ODBC/JDBC).

## Prerequisites

- Phases 2 & 4 complete (Hive Metastore Ready, Iceberg tables in MinIO).
- `platform-serving` namespace + quotas (Phase 1).

## Deploy

```bash
chmod +x scripts/bootstrap-phase5.sh
./scripts/bootstrap-phase5.sh
```

The script:
1. Installs Dremio (community Helm chart) into `platform-serving`.
2. Waits for the Dremio coordinator to be Ready.
3. Prints the port-forward command and where to drop `source-hive.json` via the Dremio REST API.

## Adding the Hive source

Once Dremio is up:

```bash
kubectl -n platform-serving port-forward svc/dremio-client 9047:9047 &
# Open http://localhost:9047 -> first-login wizard (admin user)

# Optional: create the Hive source via REST API
TOKEN=$(curl -s -X POST http://localhost:9047/apiv2/login \
  -H "Content-Type: application/json" \
  -d '{"userName":"admin","password":"REPLACE_ME"}' | jq -r .token)

curl -X POST http://localhost:9047/api/v3/catalog \
  -H "Authorization: _dremio${TOKEN}" \
  -H "Content-Type: application/json" \
  -d @bootstrap/phase-5/manifests/dremio/source-hive.json
```