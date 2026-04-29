# Memoire Projet - dataplatfrom-infrastructure

Ce fichier sert de contexte persistant pour reprendre rapidement le projet sans repartir de zero.

## 1) Identite du projet

- Nom: `dataplatfrom-infrastructure`
- Nature: Infrastructure as Code (Terraform) pour une landing zone data platform.
- Perimetre actuel: Phase 1 (fondations AWS/EKS + CI/CD + bootstrap K8s).
- Region cible: `us-east-1`.
- Backend Terraform: Cloudflare R2 (S3-compatible).

## 2) Objectif produit (ce que ce repo doit livrer)

Mettre en place une base d'infrastructure securisee et exploitable pour les phases suivantes (MinIO, Hive Metastore, Kafka, Spark, Dremio, etc.), sans workloads applicatifs dans cette phase.

## 3) Etat reel vs etat cible

### Etat cible documente

- VPC 3 AZ, sous-reseaux public/prive, NAT.
- EKS 1.30 avec deux node groups (`stateful-ng` et `compute-ng`).
- KMS CMK separees (EBS, secrets, logs).
- IAM/IRSA pour les controllers.
- Bootstrap Kubernetes (namespaces, policies, storage class, quotas).
- CI/CD GitHub Actions (plan en PR, apply apres merge avec gate dev).

### Etat reel implemente (constat actuel)

- Flux CI/CD Terraform present et structure.
- Stack `terraform/bootstrap` presente et la plus concrete.
- Wiring environnement `terraform/environments/dev` en place.
- Plusieurs modules coeur encore en squelette/TODO:
  - `terraform/modules/vpc/main.tf`
  - `terraform/modules/kms/main.tf`
  - `terraform/modules/iam/main.tf`
  - `terraform/modules/eks/main.tf`
  - `terraform/modules/r2-backend-bootstrap/main.tf`
- `bootstrap/` ne contient pas encore les manifests attendus (seulement README).

## 4) Cartographie rapide du repository

- `README.md`: vision globale, scope, layout.
- `docs/01-getting-started.md`: runbook end-to-end.
- `docs/02-architecture-decision-records.md`: ADR (choix + rationales).
- `terraform/bootstrap/`: setup initial (R2 + IAM OIDC GitHub Actions).
- `terraform/environments/dev/`: composition de l'environnement dev.
- `terraform/modules/`: modules Terraform (VPC, KMS, IAM, EKS, R2 bootstrap).
- `.github/workflows/`: pipeline plan/apply.
- `scripts/`: utilitaires local init + bootstrap cluster.
- `bootstrap/`: manifests Kubernetes post-Terraform (attendus).

## 5) Flux d'execution et exploitation

## Bootstrap one-time

1. Executer `terraform/bootstrap`.
2. Recuperer outputs (`r2_bucket_name`, role ARN GH Actions, etc.).
3. Creer token R2 API en manuel.
4. Alimenter GitHub Secrets/Variables.

## Flux normal

1. Init backend dev via `scripts/tf-init-local.sh`.
2. Ouvrir PR -> workflow `terraform-plan.yml`.
3. Merge sur `main` -> workflow `terraform-apply.yml`.
4. Gate manuelle `environment: dev`.

## Post-apply

1. Recuperer kubeconfig (`terraform output kubeconfig_command`).
2. Lancer `scripts/bootstrap-cluster.sh`.

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

## Critique

- Modules Terraform essentiels non implementes (VPC/KMS/IAM/EKS).
- Absence des manifests `bootstrap/` alors que scripts/docs les supposent.

## Important

- Permissions potentiellement trop larges pour le role GitHub Actions (MVP acceptable, a durcir).
- Presence de state local bootstrap dans le repo (`terraform/bootstrap/terraform.tfstate*`) a traiter selon politique securite.

## Operatoire

- Ecart entre promesse README et etat reel executable -> risque de confusion onboarding.

## 8) Contrats implicites a respecter

- Variables standard modules: `environment`, `name_prefix`, `tags`.
- Sorties dev attendues: `cluster_name`, `kubeconfig_command`.
- CI doit rester writer principal du state (single-writer convention).
- Naming/tags coherents entre modules et environnement.

## 9) Reprise rapide en 30 minutes (playbook)

1. Lire `README.md` puis `docs/02-architecture-decision-records.md`.
2. Verifier les workflows:
   - `.github/workflows/terraform-plan.yml`
   - `.github/workflows/terraform-apply.yml`
3. Ouvrir `terraform/environments/dev/main.tf` pour voir le wiring.
4. Verifier niveau d'implementation reel dans `terraform/modules/*/main.tf`.
5. Lancer un `terraform validate` local sur `terraform/environments/dev`.
6. Aligner backlog selon priorites section 10.

## 10) Backlog recommande (ordre de delivery)

1. Implementer `terraform/modules/vpc`.
2. Implementer `terraform/modules/kms`.
3. Implementer `terraform/modules/iam` (OIDC/IRSA).
4. Implementer `terraform/modules/eks`.
5. Ajouter manifests dans `bootstrap/` (namespaces, quotas, network policies, storage class).
6. Durcir IAM GitHub Actions (principe du moindre privilege).
7. Clarifier la strategie de gestion du state bootstrap.

## 11) Secrets et prerequis externes (memo)

- AWS profile admin (local) + acces compte cible.
- Cloudflare account + token API + credentials R2.
- GitHub Secrets:
  - `AWS_GH_ACTIONS_ROLE_ARN`
  - `CF_R2_ACCESS_KEY_ID`
  - `CF_R2_SECRET_ACCESS_KEY`
  - `CF_ACCOUNT_ID`
- GitHub Variable:
  - `TF_STATE_BUCKET`
- GitHub Environment:
  - `dev` (avec reviewer requis).

## 12) Definition de "contexte sain" pour continuer

Le contexte est considere sain si:

- les ADR restent alignes avec l'implementation,
- les workflows CI/CD passent sans contournements manuels non documentes,
- les modules Terraform critiques sont implementes et valides,
- le bootstrap Kubernetes est present et idempotent,
- et ce fichier est mis a jour apres chaque changement architectural notable.
