# Implémentation étape par étape (PFE — Cloud Data Platform)

Ce document est l’**ordre d’exécution** recommandé. À chaque étape :

- **Vous** = actions sur **votre machine** (WSL), comptes **AWS / Cloudflare / GitHub**, et **terminal**.
- **Repo** = ce qui est déjà écrit dans le dépôt (Terraform, scripts, manifests).

Les durées sont indicatives. En parallèle des `apply` longs, lisez **`docs/specs/SPEC_ALIGNMENT.md`** et les PDF du jury (**Étape D**).

---

## Étape A — Audit sécurité des fichiers d’état Terraform (~5 min)

**But :** ne jamais versionner des secrets d’infrastructure (state Terraform).

| Qui | Action |
|-----|--------|
| **Repo** | `.gitignore` contient déjà `*.tfstate`, `*.tfstate.*`, `*.tfstate.backup`. |
| **Vous** | Dans le clone du projet : `git status` ne doit pas lister de `terraform.tfstate` à commiter. |
| **Vous** | Vérifier qu’aucun state n’est suivi : `git ls-files '*.tfstate' '*.tfstate.*'` → doit être **vide**. |

**Si un `.tfstate` a déjà été commis (même une fois) :** considérer les identifiants comme exposés → **rotation** (clés AWS, token Cloudflare, clés R2) et nettoyage d’historique (`git filter-repo` / BFG) — détail hors scope de ce guide ; en cas de doute, demandez à votre encadrant.

---

## Étape B — Comprendre le state **bootstrap** (~5 min)

**But :** savoir ce que `terraform/bootstrap` a déjà créé (IAM GitHub OIDC, éventuellement bucket R2).

| Qui | Action |
|-----|--------|
| **Vous** | `cd terraform/bootstrap` |
| **Vous** | `terraform show` (ou ouvrir `terraform.tfstate` **localement** — fichier **ignoré** par Git, ne pas le commiter). |

**Décision (vous seul) :**

- **(c) MVP** : laisser le state **local** sur votre PC, **ne jamais** le commit.
- **(a)** : plus tard, migrer ce state vers un backend S3/R2 (évolution).
- **(b)** : refaire from scratch sur un compte propre (si environnement de test pollué).

**Sorties utiles :** `terraform output` → notamment `github_actions_role_arn` (secret GitHub `AWS_GH_ACTIONS_ROLE_ARN`).

---

## Étape C — Outils sur WSL (~10 min)

**But :** tout ce qui parle à AWS, Terraform et au cluster depuis **votre** terminal Linux.

| Qui | Action |
|-----|--------|
| **Vous** | Installer dans **WSL** (pas seulement Windows) : `aws` CLI v2, `terraform` ≥ 1.9, `kubectl`, `helm` ≥ 3.14, `git`, `openssl`. |
| **Vous** (optionnel) | `jq` pour lire des JSON (outputs, tests). |

Vérification rapide :

```bash
aws --version
terraform version
kubectl version --client
helm version
```

**Note :** le projet ne remplace pas ces installations sur votre poste.

---

## Étape D — Lecture « jury » (en parallèle, ~10 min +)

**But :** cadrer la soutenance avec les PDF sous `docs/specs/`.

| Qui | Action |
|-----|--------|
| **Vous** | Lire `docs/specs/SPEC_ALIGNMENT.md` (lien spec ↔ code). |
| **Vous** | Parcourir les trois PDF + `docs/02-architecture-decision-records.md` pour le « pourquoi ». |

Aucun script à lancer ici.

---

## Étape 0 (prérequis cloud) — Avant `terraform` **environnement dev**

**But :** le dossier `terraform/environments/dev` utilise un **backend** sur **Cloudflare R2** ; la CI et un `init` local ont besoin des mêmes informations.

| Qui | Action |
|-----|--------|
| **Vous** | Avoir un **bucket R2** (création manuelle ou `terraform/bootstrap` avec `create_r2_state_bucket = true` + `CLOUDFLARE_API_TOKEN` — voir `terraform/bootstrap/README.md`). |
| **Vous** | Créer un **token R2** « S3 API » (clés) dans le dashboard Cloudflare, **scopé** au bucket de state. |
| **Vous** | Dans **GitHub** → *Settings* → *Secrets and variables* : `AWS_GH_ACTIONS_ROLE_ARN`, `CF_R2_ACCESS_KEY_ID`, `CF_R2_SECRET_ACCESS_KEY`, `CF_ACCOUNT_ID` ; variable `TF_STATE_BUCKET` ; environnement **`dev`** avec relecteur pour l’apply. |

Ces valeurs ne vont **pas** dans le dépôt (fichiers `*.tfvars` déjà en `.gitignore`).

---

## Étape 1 — Bootstrap AWS + GitHub (one-shot, si pas déjà fait)

**But :** rôle IAM que GitHub Actions assumera + OIDC provider (souvent déjà fait de votre côté).

| Qui | Action |
|-----|--------|
| **Vous** | `cd terraform/bootstrap`, copier `terraform.tfvars.example` → `terraform.tfvars`, remplir `github_org`, `github_repo`, profil AWS, option R2. |
| **Vous** | `export CLOUDFLARE_API_TOKEN=...` **uniquement** si vous créez le bucket R2 via Terraform. |
| **Vous** | `terraform init` → `terraform apply` → noter `terraform output`. |

**Repo** : le code est déjà dans `terraform/bootstrap` + module `r2-backend-bootstrap` si activé.

---

## Étape 2 — Initialiser le backend **dev** en local (pour travailler depuis WSL)

**But :** que `terraform` dans `terraform/environments/dev` sache lire/écrire le state sur R2.

| Qui | Action |
|-----|--------|
| **Vous** | Exporter (dans le shell) : `TF_STATE_BUCKET`, `CF_ACCOUNT_ID`, `CF_R2_ACCESS_KEY_ID`, `CF_R2_SECRET_ACCESS_KEY`. |
| **Vous** | `export AWS_PROFILE=...` (profil avec droits de déploiement sur le compte cible). |
| **Repo** | Script : `./scripts/tf-init-local.sh terraform/environments/dev` |

Sans cette étape, un `terraform plan/apply` local ne pourra pas attacher le backend R2 (la CI, elle, injecte la config via les secrets GitHub).

---

## Étape 3 — Déployer la **Phase 1** infra (VPC, EKS, KMS, IAM)

**But :** créer la landing zone documentée dans le README.

| Qui | Action |
|-----|--------|
| **Vous** | `cd terraform/environments/dev`, copier `terraform.tfvars.example` → `terraform.tfvars`, ajuster si besoin (CIDR, endpoints API public/privé pour votre accès `kubectl`). |
| **Vous** | `terraform plan` puis `terraform apply`. **Ou** : PR vers `main`, merge, puis approval dans l’environnement GitHub `dev` pour la CI (`terraform-apply.yml`). |
| **Repo** | Modules `vpc`, `kms`, `eks`, `iam` ; composition dans `main.tf`. |

Durée typique : **15–25 min** surtout pour la création du control plane EKS.

---

## Étape 4 — Configurer **kubectl** pour joindre le cluster

**But :** parler au cluster depuis WSL.

| Qui | Action |
|-----|--------|
| **Vous** | `aws eks update-kubeconfig --name <nom-cluster> --region us-east-1` (le nom est dans les outputs Terraform : `cluster_name` ou commande affichée par `kubeconfig_command` selon `outputs.tf`). |
| **Vous** | Si l’API EKS est **privée uniquement**, depuis votre PC vous devez soit activer temporairement l’accès public limité à votre IP (`terraform.tfvars`), soit bastion / SSM — voir `docs/01-getting-started.md`. |
| **Vous** | `kubectl get nodes` → les nœuds doivent être **Ready**. |

---

## Étape 5 — Bootstrap Kubernetes **Phase 1** (namespaces, storage, réseau)

**But :** appliquer uniquement les manifests Phase 1 (pas MinIO/Kafka).

| Qui | Action |
|-----|--------|
| **Repo** | `scripts/bootstrap-cluster.sh` applique `namespaces/`, `storage-classes/`, `resource-quotas/`, `network-policies/`. |
| **Vous** | Depuis la racine du repo : `./scripts/bootstrap-cluster.sh` |

À la sortie, `kubectl get ns -l app.kubernetes.io/part-of=dataplatform` doit retourner les **9 namespaces** prévus par `Specifications_Doc_for_PFE.pdf` §2.2 : `platform-ingestion`, `platform-storage`, `platform-metastore`, `platform-compute`, `platform-orchestr`, `platform-serving`, `platform-monitoring`, `platform-logging`, `platform-security`. cert-manager est ensuite installé **dans `platform-security`** (Phase 2), pas dans un namespace séparé.

---

## Étape 6 — **Phase 2** : stockage & métastore (cert-manager, MinIO, CNPG, Hive)

**But :** alignement avec les specs (couche stockage + catalogue).

| Qui | Action |
|-----|--------|
| **Repo** | `scripts/prepare-phase2-secrets.sh` génère des fichiers `*.yaml` **gitignorés** à partir des `*.example.yaml`. |
| **Repo** | `scripts/bootstrap-phase2.sh` installe cert-manager, puis MinIO, CNPG, Hive (ordre défini dans le script). |
| **Vous** | `./scripts/prepare-phase2-secrets.sh` (relire les fichiers générés si vous voulez des mots de passe maison). |
| **Vous** | `./scripts/bootstrap-phase2.sh` |

En cas de cluster **petit**, surveillez les ressources ; ajustez les values Helm si nécessaire (mémoire/CPU).

---

## Étape 7 — **Phase 3** (optionnel, après Phase 2 stable)

**But :** Kafka (Strimzi) + NiFi.

| Qui | Action |
|-----|--------|
| **Repo** | `scripts/bootstrap-phase3.sh` |
| **Vous** | Vérifier la **taille** du Kafka par défaut (`bootstrap/phase-3/manifests/kafka/`) — répliques/volumes ; réduire en **dev** si besoin. |
| **Vous** | `./scripts/bootstrap-phase3.sh` |

---

## Mode accéléré (1 commande)

Si tes prérequis cloud sont prêts (secrets/backend R2, profil AWS, accès réseau API EKS), utilise le script d'orchestration:

```bash
chmod +x scripts/fasttrack-infra.sh

# Phase 1 + Phase 2
./scripts/fasttrack-infra.sh --auto-approve --with-phase2

# Phase 1 + Phase 2 + Phase 3
./scripts/fasttrack-infra.sh --auto-approve --with-phase2 --with-phase3
```

Le script fait: init backend dev → `terraform plan/apply` → kubeconfig → `bootstrap-cluster` → secrets Phase 2 (option) → `bootstrap-phase2` (option) → `bootstrap-phase3` (option).

---

## Cycle stop / start (économiser AWS)

But: arrêter la facturation quand vous ne travaillez pas, puis tout relancer.

### Détruire (stop)

```bash
chmod +x scripts/teardown-infra.sh
./scripts/teardown-infra.sh --auto-approve
```

Le script :
1. désinstalle les releases Helm (Strimzi, Hive, CNPG, MinIO, cert-manager) ;
2. supprime les `Service type=LoadBalancer` (libère les ELB AWS) ;
3. supprime les **PVC** dans les namespaces `platform-*` (et `cert-manager` legacy si présent) — libère les volumes EBS, sinon ils restent facturés ;
4. supprime les namespaces `platform-*` ;
5. lance `terraform destroy` dans `terraform/environments/dev` (EKS, VPC, NAT…).

Ce qui n'est **pas** détruit (volontairement, pour ne pas perdre l’état Terraform) :
- `terraform/bootstrap` (bucket S3 d’état, KMS, IAM GitHub OIDC) ;
- le bucket Cloudflare **R2** qui héberge le state distant.

> Vérifier ensuite dans la console AWS qu’il ne reste **aucune** instance EC2, NAT Gateway, ni volume EBS attaché au cluster (filtrer par tag `environment=dev`). Le NAT Gateway et l’EKS control plane sont les postes de coût les plus visibles.

### Relancer (start)

```bash
# Variables backend déjà exportées (TF_STATE_BUCKET, CF_ACCOUNT_ID, CF_R2_ACCESS_KEY_ID, CF_R2_SECRET_ACCESS_KEY, AWS_PROFILE)
./scripts/fasttrack-infra.sh --auto-approve --with-phase2
```

Comme l’état Terraform vit dans R2 (pas en local), `terraform apply` reconstruit exactement la même topologie (mêmes noms, mêmes CIDR). Les **données** dans EBS/MinIO/PostgreSQL sont par contre **perdues** (c’est attendu pour un environnement dev jetable). Pour les conserver entre cycles, il faudra plus tard ajouter du **backup S3** (CNPG Barman, MinIO replication, etc.) — pas dans le scope MVP.

## Synthèse : ordre strict des **commandes** (vous)

```text
# A — git / pas de state commité (voir section A)

# C — outils installés (aws, terraform, kubectl, helm)

# 0 — GitHub secrets + R2 + bucket

# 1 — terraform/bootstrap (si pas fait)
cd terraform/bootstrap && terraform apply

# 2 — init backend dev
cd ../..   # racine du repo
export TF_STATE_BUCKET=... CF_ACCOUNT_ID=... CF_R2_ACCESS_KEY_ID=... CF_R2_SECRET_ACCESS_KEY=...
export AWS_PROFILE=...
./scripts/tf-init-local.sh terraform/environments/dev

# 3 — Phase 1 infra
cd terraform/environments/dev && terraform apply

# 4 — kubeconfig
aws eks update-kubeconfig --name ... --region us-east-1
kubectl get nodes

# 5 — bootstrap K8s phase 1
cd ../../..   # racine
./scripts/bootstrap-cluster.sh

# 6 — Phase 2
./scripts/prepare-phase2-secrets.sh
./scripts/bootstrap-phase2.sh

# 7 — Phase 3 (optionnel)
./scripts/bootstrap-phase3.sh

# 8 — Stop facturation (fin de journée)
./scripts/teardown-infra.sh --auto-approve

# 9 — Start (lendemain)
./scripts/fasttrack-infra.sh --auto-approve --with-phase2
```

---

## Documents de référence dans le dépôt

| Fichier | Rôle |
|---------|------|
| `docs/01-getting-started.md` | Détail PR, R2, troubleshooting |
| `docs/phases/PHASE_CHECKPOINTS.md` | Jalons avant Phase 2 / 3 |
| `MEMORY.md` | Mémo contexte + plan A–F |
| `docs/specs/SPEC_ALIGNMENT.md` | Traçabilité spec ↔ code |

---

*Pour toute erreur Terraform ou `kubectl`, copiez uniquement les **lignes d’erreur** (sans secrets ni ARN complets si vous préférez)*.
