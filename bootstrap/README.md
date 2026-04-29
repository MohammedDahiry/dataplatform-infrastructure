# Cluster Bootstrap Manifests

Post-Terraform Kubernetes manifests live here:

- Namespaces
- RBAC
- Default StorageClass
- Default NetworkPolicies
- ResourceQuotas

## Current structure

- `namespaces/`: namespace creation manifests
- `resource-quotas/`: default per-namespace quotas
- `network-policies/`: default deny + DNS allow + same-namespace ingress
- `storage-classes/`: encrypted `gp3` default storage class
- `phase-2/`: baseline manifests/values for MinIO, CNPG, and Hive metastore
- `phase-3/`: baseline manifests for Strimzi Kafka and NiFi
