# Phase 7 Bootstrap (Observability — Prometheus, Grafana, Fluent Bit, OpenObserve)

Per `Specifications_Doc_for_PFE.pdf` §9.

This phase implements the **three pillars of observability**:

| Pillar | Tool | Namespace |
|--------|------|-----------|
| Metrics | kube-prometheus-stack (Prometheus + Alertmanager + Grafana) | `platform-monitoring` |
| Logs | Fluent Bit (DaemonSet) -> S3 -> OpenObserve | `platform-logging` |
| Traces | OpenTelemetry (future) | n/a |

`ServiceMonitor` CRDs are pre-wired for the platform components installed in Phases 2–4.

## Prerequisites

- Phase 1 namespaces (`platform-monitoring`, `platform-logging`).
- (Optional) Phase 6: a `TunnelBinding` for `monitoring-grafana` is shipped in
  `bootstrap/phase-6/manifests/tunnel-bindings/grafana.yaml`.

## Deploy

```bash
chmod +x scripts/bootstrap-phase7.sh
./scripts/bootstrap-phase7.sh
```

The script:
1. Adds Helm repos (`prometheus-community`, `openobserve`, `fluent`).
2. Installs `kube-prometheus-stack` into `platform-monitoring`.
3. Installs `OpenObserve` into `platform-logging`.
4. Installs `Fluent Bit` into `platform-logging` (DaemonSet).
5. Applies `ServiceMonitor` CRDs for Spark Operator, MinIO, CNPG, Strimzi.
6. Applies the Grafana dashboard `Dataplatform - Cluster State`.
7. Applies OpenObserve Kubernetes log-query snippets as a ConfigMap.

## After deploy

```bash
kubectl -n platform-monitoring port-forward svc/monitoring-grafana 3000:80
# Open http://localhost:3000  (admin / prom-operator default)

kubectl -n platform-logging port-forward svc/openobserve 5080:5080
# Open http://localhost:5080  (admin / Complexpass#123 default — change!)
```

## Cluster state dashboard

Grafana imports `Dataplatform - Cluster State` automatically through the
kube-prometheus-stack dashboard sidecar. It covers:

- node readiness and not-ready nodes;
- running, pending, failed and unknown pods;
- per-node CPU and memory usage;
- pod phase distribution;
- unhealthy pods by namespace;
- container restart details.

OpenObserve receives Kubernetes container logs through Fluent Bit. Query
snippets for pod errors, noisy pods, node log activity and crash-loop signals are
stored in:

```bash
kubectl -n platform-logging get configmap openobserve-k8s-cluster-log-queries -o jsonpath='{.data.README\.md}'
```
