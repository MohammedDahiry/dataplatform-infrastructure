# Secrets Templates

These templates are intentionally placeholders. Replace values before applying.

## Files

- `minio-admin-secret.example.yaml`
- `pg-source-app-secret.example.yaml`
- `pg-hms-app-secret.example.yaml`
- `hive-db-secret.example.yaml`

## Usage

```bash
cp bootstrap/phase-2/manifests/secrets/minio-admin-secret.example.yaml bootstrap/phase-2/manifests/secrets/minio-admin-secret.yaml
cp bootstrap/phase-2/manifests/secrets/pg-source-app-secret.example.yaml bootstrap/phase-2/manifests/secrets/pg-source-app-secret.yaml
cp bootstrap/phase-2/manifests/secrets/pg-hms-app-secret.example.yaml bootstrap/phase-2/manifests/secrets/pg-hms-app-secret.yaml
cp bootstrap/phase-2/manifests/secrets/hive-db-secret.example.yaml bootstrap/phase-2/manifests/secrets/hive-db-secret.yaml
```

Then edit all `stringData` values before applying.
