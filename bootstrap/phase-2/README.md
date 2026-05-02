# Phase 2 Bootstrap

This directory contains baseline manifests and values files for Phase 2 components:

- MinIO Operator + Tenant
- CloudNativePG PostgreSQL clusters
- Hive Metastore

## Prerequisites

- Phase 1 infrastructure applied (`terraform/environments/dev`)
- Bootstrap manifests already applied from `bootstrap/`
- EKS kubeconfig configured
- `helm` installed locally
- Copy and edit secrets from `bootstrap/phase-2/manifests/secrets/*.example.yaml`

## Suggested install order (matches `Doc (1).pdf` Phase 2)

1. **cert-manager** (TLS prerequisite — installed first by `scripts/bootstrap-phase2.sh`)
2. Secrets + RBAC (`manifests/secrets`, `manifests/rbac`)
3. MinIO Operator + Tenant
4. CloudNativePG Operator + PostgreSQL clusters
5. Hive metastore database (Bitnami PostgreSQL) + Hive ConfigMap

Gate before you start: complete **Phase 1** checkpoints in [`docs/phases/PHASE_CHECKPOINTS.md`](../../docs/phases/PHASE_CHECKPOINTS.md).

## Commands

```bash
helm repo add jetstack https://charts.jetstack.io
helm repo add minio-operator https://operator.min.io
helm repo add cnpg https://cloudnative-pg.github.io/charts
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  -f bootstrap/phase-2/helm/cert-manager-values.yaml \
  --set crds.enabled=true --wait --timeout 10m

helm upgrade --install minio-operator minio-operator/operator \
  --namespace platform-storage --create-namespace \
  -f bootstrap/phase-2/helm/minio-operator-values.yaml

kubectl apply -f bootstrap/phase-2/manifests/minio/

helm upgrade --install cnpg cnpg/cloudnative-pg \
  --namespace platform-storage --create-namespace \
  -f bootstrap/phase-2/helm/cnpg-values.yaml

kubectl apply -f bootstrap/phase-2/manifests/postgres/

helm upgrade --install hive-metastore bitnami/postgresql \
  --namespace platform-metastore --create-namespace \
  -f bootstrap/phase-2/helm/hive-postgresql-values.yaml
```

## One-command bootstrap

```bash
chmod +x scripts/bootstrap-phase2.sh
./scripts/bootstrap-phase2.sh
```
