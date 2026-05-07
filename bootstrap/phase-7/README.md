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

## After deploy

```bash
kubectl -n platform-monitoring port-forward svc/monitoring-grafana 3000:80
# Open http://localhost:3000  (admin / prom-operator default)

kubectl -n platform-logging port-forward svc/openobserve 5080:5080
# Open http://localhost:5080  (admin / Complexpass#123 default — change!)
```