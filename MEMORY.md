# Memoire Projet - dataplatform-infrastructure

Ce fichier sert de contexte persistant pour reprendre rapidement le projet sans repartir de zero.

**Derniere mise a jour:** checkpoints Phase 1/2/3 documentes (`docs/phases/PHASE_CHECKPOINTS.md`), Phase 2 script inclut **cert-manager**, namespace `cert-manager` dans `bootstrap/namespaces/`.

## 1) Identite du projet

- Nom: `dataplatform-infrastructure`
- Nature: Infrastructure as Code (Terraform) pour une landing zone data platform.
- Perimetre documente Phase 1: fondations AWS/EKS + CI/CD + bootstrap K8s (pas de workloads applicatifs).
- Extensions dans le repo: manifests et scripts **Phase 2** (MinIO, CNPG, Hive) et **Phase 3** (Kafka Strimzi, NiFi) — a executer apres Phase 1 operationnelle.
- Region cible: `us-east-1`.
- Backend Terraform (environnement `dev`): Cloudflare R2 (S3-compatible), configure en CI et via `scripts/tf-init-local.sh`.

## 2) Objectif produit (ce que ce repo doit livrer)

Mettre en place une base d'infrastructure securisee et exploitable pour les phases suivantes (MinIO, Hive Metastore, Kafka, Spark, Dremio, etc.), sans workloads applicatifs dans la Phase 1.

## 3) Etat reel vs etat cible

### Etat cible documente

- VPC 3 AZ, sous-reseaux public/prive, NAT.
- EKS (version configurable, ex. 1.30) avec deux node groups (`stateful-ng` et `compute-ng`).
- KMS CMK separees (EBS, secrets, logs).
- IAM/IRSA pour les controllers.
- Bootstrap Kubernetes (namespaces, policies, storage class, quotas).
- CI/CD GitHub Actions (plan en PR, apply apres merge avec gate `dev`).

### Etat reel implemente dans le code (constat actuel)

- **CI/CD:** workflows `terraform-plan.yml` et `terraform-apply.yml` en place (fmt, TFLint, init R2, plan/apply).
- **`terraform/environments/dev`:** composition `vpc` + `kms` + `eks` + `iam` cablee dans `main.tf`.
- **Modules Terraform cœur:** implementes (ressources reelles, pas des squelettes vides):
  - `terraform/modules/vpc`
  - `terraform/modules/kms`
  - `terraform/modules/iam`
  - `terraform/modules/eks`
- **`terraform/bootstrap`:** OIDC GitHub + role IAM pour Actions + **option** creation bucket R2 (`create_r2_state_bucket`, module `r2-backend-bootstrap`). Voir `terraform/bootstrap/README.md`.
- **`terraform/modules/r2-backend-bootstrap`:** bucket R2 (`cloudflare_r2_bucket`); `location` normalise en **majuscules** (ENAM, WNAM, …). **Cles S3 R2** pour le backend Terraform (`backend "s3"`) toujours creees **manuellement** dans le dashboard (scopes bucket).
- **`bootstrap/` (Phase 1 K8s):** present — `namespaces/`, `resource-quotas/`, `network-policies/`, `storage-classes/` + `README.md`.
- **`bootstrap/phase-2/` et `bootstrap/phase-3/`:** Helm values + manifests; **Phase 2** inclut desormais **cert-manager** en premier dans `bootstrap-phase2.sh` (aligne specs / `Doc (1).pdf`). Secrets: copier `*.example.yaml` vers fichiers **non** versionnes.
- **Scripts:** `scripts/tf-init-local.sh`, `scripts/bootstrap-cluster.sh`, `scripts/bootstrap-phase2.sh` (cert-manager → MinIO → CNPG → Hive), `scripts/bootstrap-phase3.sh` (Strimzi → Kafka → NiFi + attentes readiness).

### Ce qui reste a valider hors-repo

- Un `terraform apply` reel sur le compte AWS cible et un cluster EKS joignables.
- Secrets GitHub / variables (`TF_STATE_BUCKET`, cles R2, role ARN) et environnement `dev` avec reviewer.
- Re-appliquer `./scripts/bootstrap-cluster.sh` apres ajout du namespace `cert-manager` si le cluster existait deja avant cette evolution.

## 3 bis) Checkpoints projet (ne pas perdre le fil)

Source detaillee: **`docs/phases/PHASE_CHECKPOINTS.md`** (coche Phase 0 → 1 → 2 → 3). Resume:

| Jalons | Condition minimale avant la suite |
|--------|-------------------------------------|
| **Phase 1 terminee** | `terraform apply` dev OK, `kubectl get nodes` Ready, `./scripts/bootstrap-cluster.sh` OK, storage class **gp3** presente. |
| **Demarrer Phase 2** | `./scripts/prepare-phase2-secrets.sh` (ou copie manuelle); puis `./scripts/bootstrap-phase2.sh`. |
| **Demarrer Phase 3** | Phase 2 stable; verifier capacite cluster pour Kafka (3+ replicas par defaut dans `strimzi-kafka.yaml`) ou reduire les replicas en dev. |

Les trois PDF sous `docs/specs/` sont relies au code via **`docs/specs/SPEC_ALIGNMENT.md`**.

## 4) Cartographie rapide du repository

- `README.md`: vision globale, scope Phase 1, layout.
- `docs/01-getting-started.md`: runbook end-to-end (inclut R2 manuel, PR, apply, kubeconfig, bootstrap cluster).
- `docs/02-architecture-decision-records.md`: ADR.
- `terraform/bootstrap/`: IAM OIDC GitHub + role Actions (state local — voir risques).
- `terraform/environments/dev/`: stack dev (backend R2).
- `terraform/modules/`: `vpc`, `kms`, `iam`, `eks`, `r2-backend-bootstrap`.
- `docs/phases/PHASE_CHECKPOINTS.md`: jalons Phase 1/2/3 pour la soutenance.
- `.github/workflows/`: plan / apply Terraform.
- `scripts/`: init backend local, bootstrap cluster Phase 1, Phase 2, Phase 3.
- `bootstrap/`: manifests K8s post-Terraform Phase 1 + dossiers phase-2 / phase-3.

## 5) Flux d'execution et exploitation

### Bootstrap one-time (AWS + prerequis R2)

1. Executer `terraform/bootstrap` (role GitHub Actions + OIDC provider si besoin + **option** bucket R2 si `create_r2_state_bucket = true` et `CLOUDFLARE_API_TOKEN`).
2. Sinon / en complement: creer le bucket R2 **manuellement**; generer les **cles S3** pour le backend Terraform dans le dashboard.
3. Recuperer outputs bootstrap (`github_actions_role_arn`, etc.).
4. Alimenter GitHub Secrets / Variables (`AWS_GH_ACTIONS_ROLE_ARN`, cles R2, `CF_ACCOUNT_ID`, `TF_STATE_BUCKET`).
5. Configurer l’environnement GitHub `dev` avec approbation requise.

### Flux normal

1. Init backend dev via `scripts/tf-init-local.sh` (ou uniquement via CI).
2. Ouvrir PR vers `main` -> `terraform-plan.yml`.
3. Merge sur `main` -> `terraform-apply.yml`.
4. Gate manuelle `environment: dev`.

### Post-apply

1. Recuperer kubeconfig (`terraform output kubeconfig_command` depuis `terraform/environments/dev`).
2. Lancer `./scripts/bootstrap-cluster.sh` (Phase 1 uniquement: `namespaces/`, `storage-classes/`, `resource-quotas/`, `network-policies/`). Phase 2/3: scripts dedies.

## 6) Decisions structurantes (ADR condensees)

- Deux node groups (isoler stateful vs compute, faciliter scale-to-zero compute).
- NAT unique en dev (cout reduit, risque SPOF accepte).
- CMK dediees par usage.
- EKS access entries API au lieu de `aws-auth`.
- Endpoint API cluster prive par defaut.
- IRSA partout (pas de permissions AWS attachees aux nodes pour les workloads).
- Terraform state sur R2.
- Prefix delegation active sur VPC CNI.
- Pod Security Admission baseline par defaut.
- Lock Terraform via `use_lockfile` + serialisation CI.

Source de verite: `docs/02-architecture-decision-records.md`.

## 7) Risques et dette technique prioritaires

### Critique / important

- **State bootstrap dans le repo:** `terraform/bootstrap/terraform.tfstate*` — a traiter selon politique securite (ne pas versionner, ou remote state / chiffrement).
- **R2:** bucket peut etre cree par Terraform (module) ou a la main; **cles S3** pour `backend` Terraform toujours manuelles cote Cloudflare.
- **`bootstrap-cluster.sh`:** limite aux dossiers Phase 1 (pas `phase-2`/`phase-3`). Re-lancer apres ajout du namespace `cert-manager`.

### Important

- Permissions potentiellement trop larges pour le role GitHub Actions (MVP acceptable, a durcir).

### Operatoire

- Garder ce fichier (`MEMORY.md`) synchronise avec le code apres chaque evolution majeure.

## 8) Contrats implicites a respecter

- Variables standard modules: `environment`, `name_prefix`, `tags`.
- Sorties dev attendues: `cluster_name`, `kubeconfig_command` (et autres selon `outputs.tf`).
- CI comme writer principal du state `dev` (convention single-writer).
- Naming/tags coherents entre modules et environnement.

## 9) Reprise rapide en 30 minutes (playbook)

1. Lire `README.md` puis `docs/02-architecture-decision-records.md`.
2. Verifier les workflows: `terraform-plan.yml`, `terraform-apply.yml`.
3. Ouvrir `terraform/environments/dev/main.tf` pour le wiring.
4. Parcourir `terraform/modules/{vpc,kms,iam,eks}/main.tf` pour le niveau de detail.
5. Lancer `terraform validate` dans `terraform/environments/dev` (apres `init` si possible).
6. Parcourir `bootstrap/` et `bootstrap/phase-2` / `phase-3` pour la suite produit.
7. Aligner le backlog section 10 avec `docs/specs/SPEC_ALIGNMENT.md`.

## 10) Backlog recommande (ordre de delivery — mis a jour)

1. **Executer Phase 2 puis 3** une fois les checkpoints `PHASE_CHECKPOINTS.md` verts (secrets, capacite Kafka).
2. **Poursuivre la couverture spec** (`SPEC_ALIGNMENT.md`): Spark/Airflow/Dremio, observabilite, Zero Trust, Lambda cost, Ansible ou memo ecrit de perimeter MVP.
3. **Durcir le role GitHub Actions** (remplacer `AdministratorAccess` par politiques limitees Terraform/EKS).
4. **Politique state:** retirer ou externaliser `terraform/bootstrap/terraform.tfstate*`.

## 11) Secrets et prerequis externes (memo)

- AWS profile admin (local) + acces compte cible.
- Cloudflare account + token API + credentials R2 + bucket de state.
- GitHub Secrets: `AWS_GH_ACTIONS_ROLE_ARN`, `CF_R2_ACCESS_KEY_ID`, `CF_R2_SECRET_ACCESS_KEY`, `CF_ACCOUNT_ID`.
- GitHub Variable: `TF_STATE_BUCKET`.
- GitHub Environment: `dev` (reviewer requis).

## 12) Definition de "contexte sain" pour continuer

Le contexte est considere sain si:

- les ADR restent alignes avec l'implementation,
- les workflows CI/CD passent sans contournements manuels non documentes,
- les modules Terraform **vpc/kms/iam/eks** sont valides (`validate` / `plan`) sur l’environnement cible,
- le bootstrap Kubernetes Phase 1 est present, idempotent, et les scripts refletent ce qu’on applique reellement,
- ce fichier reflete l’etat du depot apres chaque changement architectural notable.
