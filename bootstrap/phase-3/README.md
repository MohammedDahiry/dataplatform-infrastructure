# Phase 3 Bootstrap (Kafka + NiFi)

Per `Specifications_Doc_for_PFE.pdf` §3.4 and §4.

This phase deploys the ingestion backbone:

- Strimzi Kafka Operator
- Kafka cluster (platform-ingestion)
- KafkaConnect with Debezium (PostgreSQL CDC)
- Medallion topics (`bronze.*`, `cdc.*`)
- Apache NiFi (StatefulSet baseline)

## Prerequisites

- Phase 2 is complete (cert-manager, MinIO Tenant Ready, CNPG `pg-source-cluster` Ready)
- `platform-ingestion` namespace exists
- `gp3` storage class exists

## Sizing variants

| File | When | Footprint |
|------|------|-----------|
| `manifests/kafka/strimzi-kafka.yaml` | production / multi-node | 3 brokers (200 Gi) + 3 ZK (50 Gi) |
| `manifests/kafka/strimzi-kafka-dev.yaml` | demo / single-node `compute-ng` | 1 broker (30 Gi) + 1 ZK (10 Gi) |

`scripts/bootstrap-phase3.sh` defaults to the dev variant; override with `KAFKA_VARIANT=prod`.

## Deploy

```bash
chmod +x scripts/bootstrap-phase3.sh
./scripts/bootstrap-phase3.sh                  # dev variant
KAFKA_VARIANT=prod ./scripts/bootstrap-phase3.sh
```

## What gets applied

1. Strimzi operator (Helm)
2. `Kafka` cluster (dev or prod variant)
3. `KafkaTopic` resources for Medallion topics
4. `KafkaConnect` (Debezium) + `KafkaConnector` for `pg-source-cluster` CDC
5. NiFi StatefulSet (UI on `platform-ingestion/nifi:8080`)
