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

## Suggested install order

1. Install MinIO Operator
2. Apply MinIO tenant resources
3. Install CloudNativePG Operator
4. Apply PostgreSQL cluster resources
5. Install Hive Metastore

## Commands

```bash
helm repo add minio-operator https://operator.min.io
helm repo add cnpg https://cloudnative-pg.github.io/charts
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

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
