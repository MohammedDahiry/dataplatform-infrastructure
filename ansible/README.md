# Ansible — périmètre MVP

La spécification du PFE mentionne parfois **Ansible** en complément de Terraform pour la configuration post-bootstrap.

## Décision pour ce dépôt

**Aucun playbook Ansible n’est fourni volontairement :** toute la configuration reproductible est couverte par :

- **Terraform** — VPC, EKS, IAM/IRSA, KMS, Lambda scaling optionnelle ;
- **Helm + manifests Kubernetes** — MinIO, CNPG, Hive, Strimzi, Spark Operator, Airflow, etc. ;
- **Scripts shell** sous `scripts/` — enchaînement idempotent des phases et substitution des secrets au runtime.

Cette pile répond au critère « infrastructure as code » et à une démo de soutenance sans ajouter une troisième couche d’outillage à maintenir sous la contrainte temps.

## Si le rapport doit mentionner Ansible

Tu peux formuler : *« Ansible était envisagé pour la configuration applicative fine ; pour le MVP, Helm values et ConfigMaps versionnés dans le dépôt remplissent ce rôle, ce qui limite la dérive de configuration et garde un seul pipeline de vérité (Git). »*

Pour une évolution **prod**, des playbooks pourraient cibler uniquement ce qui reste hors Helm (ex. paramètres OS sur bastions, agents hors cluster), sans dupliquer ce que fait déjà Kubernetes.
