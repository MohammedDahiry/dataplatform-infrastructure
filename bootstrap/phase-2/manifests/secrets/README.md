# Secrets Templates

These templates are intentionally placeholders. Replace values before applying.

## Files

- `minio-admin-secret.example.yaml`
- `pg-source-app-secret.example.yaml`
- `pg-hms-app-secret.example.yaml`
- `hive-db-secret.example.yaml`

## Usage (recommended)

From the repo root, generate non-committed `*.yaml` files with random values:

```bash
chmod +x scripts/prepare-phase2-secrets.sh
./scripts/prepare-phase2-secrets.sh
# Overwrite existing generated files:
./scripts/prepare-phase2-secrets.sh --force
```

Then review (or edit) the generated files and run `./scripts/bootstrap-phase2.sh`.

## Manual copy

```bash
cp bootstrap/phase-2/manifests/secrets/minio-admin-secret.example.yaml bootstrap/phase-2/manifests/secrets/minio-admin-secret.yaml
# ... same for the other three ...
```

Then replace every `REPLACE_*` placeholder before applying.
