# Memoire Projet - dataplatform-infrastructure

Ce fichier sert de contexte persistant pour reprendre rapidement le projet sans repartir de zero.

**Derniere mise a jour du constat repo:** aligne sur l'etat du code (modules Terraform, `bootstrap/`, phases 2-3 en squelette).

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
- **`terraform/bootstrap`:** stack **AWS uniquement** — OIDC GitHub + role IAM pour Actions (voir `terraform/bootstrap/README.md`). Pas de creation de bucket R2 dans ce stack.
- **`terraform/modules/r2-backend-bootstrap`:** **non utilise**; `main.tf` ne contient qu'un commentaire TODO (bucket R2 a creer manuellement / hors module pour l’instant).
- **`bootstrap/` (Phase 1 K8s):** present — `namespaces/`, `resource-quotas/`, `network-policies/`, `storage-classes/` + `README.md`.
- **`bootstrap/phase-2/` et `bootstrap/phase-3/`:** valeurs Helm, manifests d’exemple (secrets `.example.yaml`), runbooks et scripts d’installation; **non** inclus dans le scope “Phase 1 livree” du README racine.
- **Scripts:** `scripts/tf-init-local.sh`, `scripts/bootstrap-cluster.sh`, `scripts/bootstrap-phase2.sh`, `scripts/bootstrap-phase3.sh`.

### Ce qui reste a valider hors-repo

- Un `terraform apply` reel sur le compte AWS cible et un cluster EKS joignables.
- Secrets GitHub / variables (`TF_STATE_BUCKET`, cles R2, role ARN) et environnement `dev` avec reviewer.
- Alignement README racine vs `terraform/bootstrap` (le README mentionne parfois un bootstrap R2 “dans Terraform” alors que le bootstrap actuel ne cree que l’IAM GitHub).

## 4) Cartographie rapide du repository

- `README.md`: vision globale, scope Phase 1, layout.
- `docs/01-getting-started.md`: runbook end-to-end (inclut R2 manuel, PR, apply, kubeconfig, bootstrap cluster).
- `docs/02-architecture-decision-records.md`: ADR.
- `terraform/bootstrap/`: IAM OIDC GitHub + role Actions (state local — voir risques).
- `terraform/environments/dev/`: stack dev (backend R2).
- `terraform/modules/`: `vpc`, `kms`, `iam`, `eks`, `r2-backend-bootstrap` (stub).
- `.github/workflows/`: plan / apply Terraform.
- `scripts/`: init backend local, bootstrap cluster Phase 1, Phase 2, Phase 3.
- `bootstrap/`: manifests K8s post-Terraform Phase 1 + dossiers phase-2 / phase-3.

## 5) Flux d'execution et exploitation

### Bootstrap one-time (AWS + prerequis R2)

1. Executer `terraform/bootstrap` (role GitHub Actions + OIDC provider si besoin).
2. Creer le bucket R2 et un token API R2 **manuellement** (dashboard Cloudflare), sauf si le module `r2-backend-bootstrap` est implemente plus tard.
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

- **State bootstrap dans le repo:** `terraform/bootstrap/terraform.tfstate*` — a traiter selon politique securite (ne pas versionner, ou chiffrer / remote state).
- **Module `r2-backend-bootstrap`:** vide; creation bucket R2 reste manuelle — documenter partout de la meme facon.
- **`bootstrap-cluster.sh`:** limite aux dossiers Phase 1 (plus de apply recursif sur `phase-2`/`phase-3`).

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
7. Aligner le backlog section 10 selon la prochaine priorite (cloud vs squelette R2 vs script bootstrap).

## 10) Backlog recommande (ordre de delivery — mis a jour)

1. **Implementer ou supprimer** `terraform/modules/r2-backend-bootstrap` (Terraform Cloudflare pour bucket R2, ou supprimer le module et clarifier la doc).
2. **Aligner la doc** (`README.md`, `docs/01-getting-started.md`) avec le contenu reel de `terraform/bootstrap` (IAM seul vs R2 dans Terraform).
3. **Valider en cloud:** premier `apply` dev + `bootstrap-cluster` + checks `kubectl` du getting-started.
4. **Durcir IAM GitHub Actions** (moindre privilege).
5. **Politique state:** retirer ou externaliser `terraform/bootstrap/terraform.tfstate*`.

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
