# Phase 10 Bootstrap (ArgoCD — optional GitOps)

Per `Specifications_Doc_for_PFE.pdf` §13. Optional. If you adopt ArgoCD, it
replaces the `helm upgrade` step in CI with declarative Git-driven sync.

## Components

- ArgoCD installed via the official Helm chart into `platform-security`
  (it acts as a control-plane component; isolating it next to cert-manager keeps
  the security boundary tight).
- An `AppProject` `dataplatform` scoped to the platform-* namespaces.
- Example `Application` CRDs that mirror the Helm releases of Phases 2–7
  (MinIO Operator, CNPG, Hive, Spark Operator, Airflow, Dremio, kube-prometheus-stack).

## Deploy

```bash
chmod +x scripts/bootstrap-phase10.sh
./scripts/bootstrap-phase10.sh
```

## After deploy

```bash
kubectl -n platform-security port-forward svc/argocd-server 8443:443
# Open https://localhost:8443
# Initial admin password:
kubectl -n platform-security get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

## Wiring your repo

Update `manifests/applications/*.yaml` `spec.source.repoURL` to point at the
GitOps repo (separate from this infra repo) that contains the Helm values you want
ArgoCD to reconcile against.