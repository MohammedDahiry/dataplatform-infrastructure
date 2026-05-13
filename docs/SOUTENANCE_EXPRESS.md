# Soutenance express — moins de 2 mois

Ce document priorise le **minimum démontrable** pour le jury et le **rapport**, quand le temps de déploiement et de rédaction est limité. Il complète `IMPLEMENTATION_ETAPES.md`, `PHASE_CHECKPOINTS.md` et `STARTUP_GUIDE.md`.

## Ce que l’IA / le dépôt ne peut pas faire à ta place

- Un **`terraform apply`** sur **ton** compte AWS, les **secrets** GitHub / Cloudflare, et l’accès **kubectl** au cluster.
- La **rédaction** du mémoire et les **captures d’écran** de la démo.

---

## Procédure pas à pas — lancer les services et la Phase Cloudflare

### Avant tout (une fois)

1. **Outils WSL** : `aws`, `terraform`, `kubectl`, `helm`, `docker`, `git`, `openssl` (voir `IMPLEMENTATION_ETAPES` étape C).

2. **Comptes** : AWS (profil CLI), Cloudflare (zone DNS + Zero Trust), bucket **R2** + clés API S3 pour le state Terraform.

3. **GitHub** : secrets `AWS_GH_ACTIONS_ROLE_ARN`, `CF_R2_ACCESS_KEY_ID`, `CF_R2_SECRET_ACCESS_KEY`, `CF_ACCOUNT_ID`, variable `TF_STATE_BUCKET`, environnement **`dev`** avec relecteur pour l’apply CI.

4. **Bootstrap Terraform IAM** (si pas déjà fait) :

   ```bash
   cd terraform/bootstrap
   # terraform.tfvars depuis .example
   terraform init && terraform apply
   ```

   Noter `github_actions_role_arn` → secret GitHub ci-dessus.

### Backend dev + variables shell

5. Exporter dans ton terminal (ou `.envrc`) :

   ```bash
   export AWS_PROFILE=ton-profil
   export TF_STATE_BUCKET=...
   export CF_ACCOUNT_ID=...
   export CF_R2_ACCESS_KEY_ID=...
   export CF_R2_SECRET_ACCESS_KEY=...
   ```

6. Initialiser le backend **dev** :

   ```bash
   ./scripts/tf-init-local.sh terraform/environments/dev
   ```

### Terraform dev + kubeconfig

7. Copier et éditer **`terraform/environments/dev/terraform.tfvars`** :

   - `cluster_endpoint_public_access_cidrs` = ta IP publique en `/32` (voir `curl -s https://api.ipify.org`).
   - Ajuster tailles de node groups si besoin (cluster petit = réduire).

8. Appliquer l’infra (ou PR + merge + approval CI) :

   ```bash
   terraform -chdir=terraform/environments/dev apply
   ```

9. Configurer **kubectl** :

   ```bash
   eval "$(terraform -chdir=terraform/environments/dev output -raw kubeconfig_command)"
   kubectl get nodes
   ```

### Phase Cloudflare (Tunnel + secrets) — **avant** `fasttrack --with-all`

10. Dans le **dashboard Cloudflare** :

    - **Zero Trust → Networks → Tunnels** → créer un tunnel (ex. `dataplatform-dev`), noter l’**UUID** du tunnel et le **secret** (champ `TunnelSecret` / credentials).
    - **My Profile → API Tokens** : token avec au minimum `Account.Cloudflare Tunnel:Edit` et `Zone.DNS:Edit` sur ta zone.

11. Générer les fichiers secrets Phase 6 (non versionnés) et remplacer les placeholders dans les manifests :

    ```bash
    ./scripts/configure-cloudflare.sh
    ```

    Le script écrit notamment `bootstrap/phase-6/manifests/secrets/cloudflare-api-token.yaml`, `cloudflare-tunnel-credentials.yaml`, et met à jour `REPLACE_ME_*` dans `helm/`, `cluster-tunnel/`, `tunnel-bindings/`. Détail : `docs/STARTUP_GUIDE.md` §8.

    **Important :** sans cette étape, **`./scripts/fasttrack-infra.sh --with-all`** s’arrête tout au début avec un message explicite (Phase 6 activée mais secrets absents).

### Image Spark + déploiement des phases 2 à 7

12. **Build / push** l’image utilisée par Spark/Airflow (nécessite ECR créé par Terraform) :

    ```bash
    chmod +x scripts/build-spark-image.sh
    ./scripts/build-spark-image.sh
    ```

13. Lancer **tout le bootstrap Kubernetes** (Phases 2 → 7, ordre géré par le script) :

    ```bash
    chmod +x scripts/fasttrack-infra.sh
    ./scripts/fasttrack-infra.sh --auto-approve --with-all
    ```

    Cela enchaîne : Terraform dev (sauf si tu utilises `--skip-terraform` après un apply déjà fait), `bootstrap-cluster.sh`, autoscaler, Phase 2… jusqu’à Phase 7. La **Phase 6** exécute `./scripts/bootstrap-phase6.sh` une fois les secrets présents.

14. **Après Phase 6** : dans **Cloudflare Zero Trust**, créer les **Access Applications** pour les FQDN du type `airflow.dataplatform.<ta-zone>`, `dremio.…`, `grafana.…`, `nifi.…` (SSO GitHub / politiques). Sans ça, le tunnel répond mais l’accès utilisateur n’est pas verrouillé comme en prod.

### Vérifications rapides

```bash
kubectl get ns -l app.kubernetes.io/part-of=dataplatform
kubectl -n platform-security get clustertunnel,tunnelbinding 2>/dev/null || true
kubectl -n platform-ingestion get kafka,pod
kubectl -n platform-compute get sparkapplications
kubectl -n platform-orchestr get pods
```

---

## Variante sans Cloudflare (port-forward uniquement)

Si tu n’as pas encore la zone / le tunnel :

1. Ne génère **pas** les secrets Phase 6.
2. Lance sans tunnel :

   ```bash
   ./scripts/fasttrack-infra.sh --auto-approve \
     --with-phase2 --with-phase3 --with-phase4 --with-phase5 --with-phase7
   ```

   (Pas `--with-phase6` ni `--with-all`.)

3. Accès UI : `kubectl port-forward` comme dans `STARTUP_GUIDE.md` (Airflow 8080, Dremio 9047, Grafana 3000, etc.).

---

## Commencer l’implémentation « données » (pipeline médaille)

Une fois les phases **2 → 4** OK :

| Étape | Action |
|-------|--------|
| **CDC / Bronze Kafka** | Vérifier le connecteur Debezium (`kubectl -n platform-ingestion …`). Les topics `bronze.*` / `cdc.*` sont créés en Phase 3. |
| **Fichiers landing** | Déposer CSV/XLSX sur MinIO dans le bucket prévu (`s3a://landing/files/…` — voir `IMPLEMENTATION_ETAPES` et `docker/spark-iceberg`). |
| **DAGs Airflow** | Éditer `dags/*.py`, puis `./scripts/prepare-airflow-dags.sh` pour rebuild le ConfigMap. |
| **dbt Silver / Gold** | Modifier `dbt/` (models), jobs via DAG `silver_gold_dbt` ou SparkApplication `dbt-run`. |
| **Dremio** | Ajouter la source Hive + MinIO (UI ou `bootstrap/phase-5/manifests/dremio/source-hive.json`) — voir `STARTUP_GUIDE.md` §7. |
| **NiFi** | Configurer les processors en UI (captures pour le rapport ; flows souvent procéduraux en MVP). |

Référence longue : **`docs/STARTUP_GUIDE.md`** (pipeline fichier → Iceberg, DAGs, cycle teardown).

---

## Périmètre « jury » minimal (rappel)

| Priorité | Phase | Contenu |
|----------|--------|---------|
| **P0** | 0 + 1 | AWS, R2, GitHub, EKS, namespaces, `gp3` |
| **P0** | 2–4 | Stockage, CDC Kafka, Spark, Airflow, dbt |
| **P1** | 5 + 7 | Dremio, observabilité |
| **P1** | **6** | **Cloudflare Tunnel + Access** (exposition sécurisée — fort impact rapport § sécurité / Zero Trust) |
| **P2** | 9–10 | Lambda scaling, ArgoCD (optionnel) |

---

## Rédaction du rapport — mapping preuve dans le repo

| Chapitre / section | Fichiers ou dossiers |
|---------------------|----------------------|
| Contexte & besoins | `docs/specs/`, `SPEC_ALIGNMENT.md` |
| Architecture | `docs/02-architecture-decision-records.md`, `README.md` |
| Sécurité / exposition | `bootstrap/network-policies/`, `bootstrap/phase-6/`, `terraform/modules/{iam,kms,eks}` |
| Déploiement | `terraform/environments/dev`, `.github/workflows/` |
| Pipeline données | `bootstrap/phase-{3,4}/`, `docker/spark-iceberg/`, `dbt/`, `dags/` |
| Observabilité | `bootstrap/phase-7/` |
| Ansible | `ansible/README.md` |

---

## Si tu dois privilégier l’écriture du mémoire

1. Figée ce qui est **versionné** + `SPEC_ALIGNMENT.md`.
2. Garde une section « mise en œuvre » avec les commandes de ce fichier et de `IMPLEMENTATION_ETAPES.md`.
3. Mentionne les limites MVP (données jetables après `teardown-infra.sh`, NiFi procédural, durcissement TLS prod).

Pour le cycle destroy / rebuild complet : **`docs/STARTUP_GUIDE.md`**.
