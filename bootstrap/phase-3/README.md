# Phase 3 Bootstrap (Kafka + NiFi)

This phase deploys the ingestion backbone:

- Strimzi Kafka Operator
- Kafka cluster (platform-ingestion)
- Apache NiFi (StatefulSet baseline)

## Prerequisites

- Phase 2 is complete
- `platform-ingestion` namespace exists
- `gp3` storage class exists

## Deploy

```bash
chmod +x scripts/bootstrap-phase3.sh
./scripts/bootstrap-phase3.sh
```
