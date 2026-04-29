# Architecture Decision Records — Phase 1

Each major design choice is captured here so future-you (or your jury) can ask
"why this and not that?" and get a one-paragraph answer instead of digging
through commit messages.

---

## ADR-001 — Two node groups, not one

**Decision:** Two managed node groups (`stateful-ng` always-on, `compute-ng`
scale-to-zero), not a single combined group.

**Why:** The cost-optimisation Lambda from §12 of the SoW must be able to scale
the compute group to zero outside business hours **without disturbing MinIO
or PostgreSQL**, which would corrupt or stall the data plane. Separating the
groups is the only safe way to do this. Stateful pods get a `workload=stateful`
toleration; nothing else lands on those nodes by accident.

**Trade-off:** ~3 nodes always running (~$210/mo) instead of dynamic. Acceptable
for an MVP and necessary for any production data platform.

---

## ADR-002 — Single NAT gateway in dev

**Decision:** One NAT gateway for the whole VPC; all three private subnets
route through it.

**Why:** A NAT gateway costs ~$32/mo plus egress fees. Three of them adds up to
~$96/mo before any data is moved. For an MVP with a 12-week budget, the
single-NAT trade-off is sound.

**Trade-off:** AZ-level SPOF. If `us-east-1a` goes down, all egress breaks.
Documented as a known risk; promoted to per-AZ NAT in `prod` via the
`single_nat_gateway = false` flag.

---

## ADR-003 — Customer-managed KMS keys, three of them

**Decision:** Three CMKs (`ebs`, `secrets`, `logs`) instead of one shared key
or AWS-managed keys.

**Why:** Each key has a distinct revocation/rotation profile and a distinct
audit story. If we ever need to rotate the secrets key (e.g. compliance
incident), it doesn't bring down EBS-attached pods. CloudTrail's `kms:Decrypt`
events are immediately readable: you can tell at a glance whether logs were
read vs. secrets vs. block storage.

**Trade-off:** $3/mo. Trivial. The key-policy boilerplate is also trivial since
all three keys share the same trust template.

---

## ADR-004 — EKS access entries, not aws-auth ConfigMap

**Decision:** `authentication_mode = "API"` and explicit `aws_eks_access_entry`
resources. No `kubernetes_config_map.aws-auth`.

**Why:** Access entries (GA September 2024) are AWS's strategic direction. They
remove the chicken-and-egg "you can't fix aws-auth if aws-auth is broken"
class of incidents, and they're managed by Terraform's `aws` provider — no
need for a `kubernetes` provider just to reach the cluster's own config map.

**Trade-off:** None for new clusters. For migrating clusters there's a one-way
upgrade path; not relevant here.

---

## ADR-005 — Cluster API endpoint private by default

**Decision:** `cluster_endpoint_public_access = false`. Public access is
opt-in via tfvars and scoped to specific CIDRs.

**Why:** Defence in depth. The Kubernetes API is the most powerful blast-radius
target in the cluster. Per the SoW §7, Cloudflare Tunnel is the user-facing
ingress; admins reach the API through the same tunnel or via Session Manager
to a bastion.

**Trade-off:** Initial bring-up is mildly awkward — you flip public access
true with your IP, run `bootstrap-cluster.sh`, flip it back. Documented in
the getting-started runbook.

---

## ADR-006 — IRSA for everything, never node-attached policies

**Decision:** The shared node IAM role has only the four AWS-managed policies
required for EKS itself (`AmazonEKSWorkerNodePolicy`, `AmazonEKS_CNI_Policy`,
`AmazonEC2ContainerRegistryReadOnly`, `AmazonSSMManagedInstanceCore`). Every
controller's AWS access goes through IRSA, scoped to a specific
ServiceAccount.

**Why:** The blast radius of a compromised pod with node-credentials is the
union of every controller's permissions. With IRSA, a compromised pod has
exactly its own controller's permissions and no more. EKS Pod Identity is the
newer alternative and gets installed alongside via the addon — both are
supported.

**Trade-off:** A slightly more elaborate IAM module. Worth it.

---

## ADR-007 — Cloudflare R2 for state, not AWS S3

**Decision:** Terraform state lives on Cloudflare R2.

**Why:** Per the SoW §10.1.1: keeping state outside AWS removes the "AWS account
compromise = state file unreachable" failure mode. R2 is S3-compatible and
free under 10 GB.

**Trade-off:** No DynamoDB-style locking. We use the new `use_lockfile = true`
backend setting (TF 1.10+) plus a CI concurrency group keyed on `dev` to
ensure single-writer semantics.

---

## ADR-008 — VPC CNI prefix delegation enabled

**Decision:** The vpc-cni addon is configured with
`ENABLE_PREFIX_DELEGATION=true`.

**Why:** Without it, an `m6i.large` is capped at 29 pods (ENI limit). With
prefix delegation, the same instance can host hundreds. We hit the cap fast
once kube-system, monitoring, and a couple of Spark drivers all schedule
together.

**Trade-off:** Negligible memory overhead on the node. Effectively free.

---

## ADR-009 — Pod Security Admission "baseline" by default

**Decision:** Every workload namespace has
`pod-security.kubernetes.io/enforce: baseline`. The security namespace is
`privileged` because cert-manager and similar controllers need it.

**Why:** PSA replaced PodSecurityPolicies in K8s 1.25. `baseline` blocks the
most egregious mistakes (host network, privileged containers, hostPath mounts)
without breaking common workloads. Dropping to `restricted` would block
workloads that legitimately need `runAsRoot`, like MinIO at first run.

**Trade-off:** Phase 2 may need to relax specific namespaces for specific
operators. Done at the namespace level via `kubectl label`.

---

## ADR-010 — `use_lockfile` instead of DynamoDB

**Decision:** The S3 backend uses `use_lockfile = true` (TF 1.10+) which
writes a `.tflock` sibling object instead of acquiring a DynamoDB lock.

**Why:** DynamoDB doesn't exist on R2. The new lockfile mechanism uses
S3 conditional writes (If-None-Match) which R2 supports. Combined with the
GitHub Actions concurrency group on `dev`, we have single-writer guarantees
at two layers.

**Trade-off:** Local concurrent runs aren't perfectly safe. Mitigated by the
convention that CI is the only writer in steady state.
