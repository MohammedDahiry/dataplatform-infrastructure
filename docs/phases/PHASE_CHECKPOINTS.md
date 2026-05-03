# Phase checkpoints — when to run what

This file is the **operational contract** between the three PDF specs (`docs/specs/`) and the repo. Use it so you do not start Phase 2 or 3 before the platform is ready.

## Phase 0 — Accounts & GitHub (one-time)

- [ ] AWS account + CLI profile (e.g. `dataplatform-admin`).
- [ ] Cloudflare: R2 state bucket exists; **S3 API** keys for Terraform backend created; `TF_STATE_BUCKET`, `CF_R2_*`, `CF_ACCOUNT_ID` in GitHub.
- [ ] `terraform/bootstrap` applied: `github_actions_role_arn` → secret `AWS_GH_ACTIONS_ROLE_ARN`.
- [ ] GitHub Environment **`dev`** with required reviewer (gates `terraform apply`).

## Phase 1 — Landing zone (Terraform + K8s baseline)

**Done in code:** `terraform/environments/dev`, `bootstrap/namespaces|network-policies|resource-quotas|storage-classes`, `scripts/bootstrap-cluster.sh`, CI workflows.

**You are ready for the next step when:**

- [ ] `terraform apply` for **dev** completed (VPC, EKS, KMS, IAM).
- [ ] `aws eks update-kubeconfig` works; `kubectl get nodes` shows Ready nodes.
- [ ] `./scripts/bootstrap-cluster.sh` ran successfully (idempotent).
- [ ] `kubectl get ns -l app.kubernetes.io/part-of=dataplatform` includes **`cert-manager`** after you re-ran bootstrap post-upgrade (or `kubectl apply -f bootstrap/namespaces/` once).

**Stop here** until all boxes are checked. Phase 2 installs operators that assume Phase 1 namespaces and storage class **`gp3`**.

---

## Phase 2 — Storage & catalog (MinIO, CNPG, Hive)

**Aligned with:** `Doc (1).pdf` Phase 2–3, `Specifications_Doc_for_PFE.pdf` (MinIO, Hive), pedagogical guide.

**Start Phase 2 only when Phase 1 checkpoint above is complete.**

1. Generate secrets (random values, **gitignored**):

   ```bash
   chmod +x scripts/prepare-phase2-secrets.sh scripts/bootstrap-phase2.sh
   ./scripts/prepare-phase2-secrets.sh
   ```

   Or copy/edit manually from `*.example.yaml` per `bootstrap/phase-2/manifests/secrets/README.md`.

2. Run:

   ```bash
   ./scripts/bootstrap-phase2.sh
   ```

The script installs **cert-manager** first (TLS prerequisite per spec), then MinIO operator/tenant, CNPG, PostgreSQL clusters, Hive metastore DB + config.

**Phase 2 is “good enough” for defense when:** pods are Running in `platform-storage`, `platform-metastore`; MinIO tenant reachable inside cluster; CNPG clusters Ready.

---

## Phase 3 — Ingestion (Kafka, NiFi)

**Aligned with:** `Doc (1).pdf` Phase 3 (Strimzi, NiFi, CDC as procedural).

**Start Phase 3 only when:**

- [ ] Phase 2 checkpoint satisfied (at minimum: `platform-ingestion` usable, storage class bound, no blocking CrashLoops for Phase 2 core).
- [ ] Cluster has **enough capacity** for Kafka (default manifest uses **3** Kafka + **3** ZooKeeper replicas with persistent volumes). For small dev clusters, reduce replicas in `bootstrap/phase-3/manifests/kafka/strimzi-kafka.yaml` *before* apply.

Then:

```bash
chmod +x scripts/bootstrap-phase3.sh
./scripts/bootstrap-phase3.sh
```

NiFi / CDC flows are **configured in NiFi UI** (spec expectation) — capture screenshots for the jury.

---

## After Phase 3 (spec roadmap, not yet automated here)

Phases 4–10 (Spark, Airflow, Dremio, Zero Trust, full observability, Lambda cost, ArgoCD) are tracked in `docs/specs/SPEC_ALIGNMENT.md`.

---

*Last updated together with `MEMORY.md` checkpoints.*
