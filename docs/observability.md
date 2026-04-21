# Observability stack

The chart ships an optional, self-contained observability stack that runs in its own namespace (`observability` by default) and is disabled out of the box. It bundles three independent components that can each be toggled on or off:

| Component | Kind | Purpose |
|---|---|---|
| **OTel Collector** | DaemonSet (+ Service) | Scrapes host / kubelet / Prometheus metrics from every node and, optionally, forwards everything via OTLP/HTTP to a remote backend. Also terminates OTLP traffic sent by the application pods. |
| **kube-state-metrics** | Deployment + Service | Exposes Kubernetes resource state (pods, deployments, PVCs, jobs, ingresses, …) as Prometheus metrics. |
| **node-problem-detector** | DaemonSet | Reports node-level problems (kernel oops, OOM kills, read-only filesystems, container runtime issues) as Node conditions and events. |

## Data flow

```
            ┌────────────────────────────────────────────────┐
            │                application pods                │
            │      (bff / engine / web, OTEL_* envs)         │
            └──────────────────┬─────────────────────────────┘
                               │ OTLP/HTTP :4318
                               ▼
 ┌───────────────────────────────────────────────────────────┐
 │   OTel Collector DaemonSet  (observability namespace)     │
 │                                                           │
 │   receivers:    otlp, hostmetrics, kubeletstats,          │
 │                 prometheus (k3s-supervisor)               │
 │   processors:   memory_limiter, batch, resource           │
 │   exporters:    prometheus :9464   (local scrape)         │
 │                 otlphttp            (remote, optional)    │
 └──────────────────┬────────────────────────────┬───────────┘
                    │                            │
                    ▼                            ▼
        ┌────────────────────┐       ┌────────────────────────┐
        │ In-cluster Prom /  │       │ Remote OTLP backend    │
        │ Grafana Agent etc. │       │ (Grafana Cloud, …)     │
        └────────────────────┘       └────────────────────────┘
```

`kube-state-metrics` and `node-problem-detector` expose their own Prometheus endpoints with `prometheus.io/scrape: "true"` annotations so any scraper (including the bundled collector via the `prometheus` receiver if you add more scrape configs) can pick them up.

## Deployment modes

There are two canonical shapes. Both are produced by the same values tree; only the `otlphttp` block differs.

### 1. On-premise (no auth)

The collector forwards to a backend reachable on the trusted network (e.g. Grafana / Tempo / Prometheus running inside the cluster or in a LAN). No `Authorization` header is needed and no secret is created.

```yaml
observability:
  enabled: true
  otelCollector:
    enabled: true
    otlphttp:
      endpoint: "http://otel-gateway.internal:4318"
      # authHeader and existingSecret left empty -> no auth
```

Rendered `otlphttp` exporter (excerpt):

```yaml
exporters:
  otlphttp:
    endpoint: "http://otel-gateway.internal:4318"
  prometheus:
    endpoint: 0.0.0.0:9464
```

### 2. Cloud (Grafana Cloud or similar)

The collector needs to authenticate against a public OTLP endpoint. The header is taken from a Kubernetes Secret so the token never sits in `values.yaml` on disk.

**Preferred:** reference an existing secret you manage out of band:

```yaml
observability:
  enabled: true
  otelCollector:
    enabled: true
    otlphttp:
      endpoint: "https://otlp-gateway-prod-sa-east-1.grafana.net/otlp"
      existingSecret: "grafana-otlp-auth"     # must contain key "Authorization"
      existingSecretKey: "Authorization"
```

Create the secret separately:

```bash
kubectl -n observability create secret generic grafana-otlp-auth \
  --from-literal=Authorization="Basic $(printf 'INSTANCE_ID:GRAFANA_TOKEN' | base64 -w0)"
```

**Fallback (not recommended for production):** inline the header in values. The chart will create a managed secret `<release>-otel-collector-auth` for you:

```yaml
observability:
  otelCollector:
    otlphttp:
      endpoint: "https://otlp-gateway-prod-sa-east-1.grafana.net/otlp"
      authHeader: "Basic <base64(instance_id:token)>"
```

In both cloud variants the collector container gets `OTEL_AUTHORIZATION` injected from the secret and the config substitutes it at runtime:

```yaml
exporters:
  otlphttp:
    endpoint: "https://otlp-gateway-prod-sa-east-1.grafana.net/otlp"
    headers:
      Authorization: ${env:OTEL_AUTHORIZATION}
```

## Application instrumentation (`observability.apps`)

The `otel:` section that used to live at the top of `values.yaml` is now `observability.apps:`. It controls the OTel env vars injected into the `bff`, `engine` and `web` pods (`OTEL_EXPORTER_OTLP_ENDPOINT`, `OTEL_EXPORTER_OTLP_PROTOCOL`, `OTEL_RESOURCE_ATTRIBUTES`, `OTEL_SERVICE_NAME`, …).

Default behavior:

- When `observability.enabled: true`, `apps.enabled` is also `true` — you do **not** have to flip a separate flag to instrument the apps.
- `OTEL_EXPORTER_OTLP_ENDPOINT` is resolved by the chart in this order:

  1. `observability.apps.exporterOtlpEndpoint` — explicit override. Apps ship OTLP directly there, bypassing the internal collector.
  2. If step 1 is empty **and** `observability.otelCollector.enabled: true` → `http://<release>-otel-collector.<ns>.svc.cluster.local:4318`. This is the recommended path: apps only talk to the in-cluster collector and the collector handles remote forwarding/auth.
  3. Otherwise empty (apps run effectively without OTel export).

### Typical configurations

| Goal | Values |
|---|---|
| Only ship host/K8s metrics, no app traces/metrics | `observability.enabled: true`, `apps.enabled: false` |
| Apps → internal collector → on-prem backend | `observability.enabled: true`, `otelCollector.otlphttp.endpoint: "http://gateway.internal:4318"` |
| Apps → internal collector → Grafana Cloud | `observability.enabled: true`, `otelCollector.otlphttp.endpoint: "https://…grafana.net/otlp"`, `otelCollector.otlphttp.existingSecret: "grafana-otlp-auth"` |
| Apps → Grafana Cloud directly (no collector) | `observability.enabled: true`, `otelCollector.enabled: false`, `apps.exporterOtlpEndpoint: "https://…grafana.net/otlp"`, `apps.exporterOtlpHeaders: "Authorization=Basic …"` |
| Observability stack off completely (default) | `observability.enabled: false` |

## Reference: key values

```yaml
observability:
  enabled: false                # master switch for the whole stack
  createNamespace: true
  namespace: observability
  cluster: "alquimia-slight"    # added as resource attribute "cluster"

  apps:
    enabled: true               # gated by observability.enabled
    logsEnabled: "true"
    exporterOtlpProtocol: "http/protobuf"
    exporterOtlpEndpoint: ""    # see resolution order above
    resourceAttributes: "deployment.environment=appliance,service.namespace=argos"
    exporterOtlpHeaders: ""
    serviceNames:
      bff: argos-bff
      engine: argos-engine
      web: argos-web

  otelCollector:
    enabled: true
    image: { repository: otel/opentelemetry-collector-contrib, tag: "0.123.0" }
    collectionInterval: 30s
    serviceName: "otel-node-monitor"
    otlphttp:
      endpoint: ""              # empty = no remote export, only local Prometheus
      authHeader: ""            # inline bearer; prefer existingSecret instead
      existingSecret: ""
      existingSecretKey: "Authorization"
    prometheusExporter:
      enabled: true
      port: 9464
    prometheusScrape:
      jobName: "k3s-supervisor"
      targets: ["127.0.0.1:6443"]

  kubeStateMetrics:
    enabled: true
    image: { repository: registry.k8s.io/kube-state-metrics/kube-state-metrics, tag: "v2.17.0" }
    service: { port: 8080 }

  nodeProblemDetector:
    enabled: true
    image: { repository: registry.k8s.io/node-problem-detector/node-problem-detector, tag: "v0.8.20" }
```

See [`charts/alquimia-slight/values.yaml`](../charts/alquimia-slight/values.yaml) for the authoritative list and default resource requests/limits.

## Resources created by the chart

All resources are named `<release>-<component>` and live in the `observability` namespace (cluster-scoped resources are prefixed too to avoid collisions when the chart is installed more than once):

| Component | Resources |
|---|---|
| OTel Collector | `ServiceAccount`, `ClusterRole`, `ClusterRoleBinding`, `ConfigMap <...>-config`, optional `Secret <...>-auth`, `DaemonSet`, `Service` (ports `4317` grpc, `4318` http, `9464` prom) |
| kube-state-metrics | `ServiceAccount`, `ClusterRole`, `ClusterRoleBinding`, `Deployment`, `Service` (`8080` http-metrics) |
| node-problem-detector | `ServiceAccount`, `ClusterRole`, `ClusterRoleBinding`, `ConfigMap <...>-config`, `DaemonSet` |

## Notes and caveats

- The OTel Collector DaemonSet runs with `hostNetwork: true` to scrape `kubeletstats` and local Prometheus endpoints (k3s supervisor on `127.0.0.1:6443`). Ports `4317`, `4318` and `9464` therefore occupy those TCP ports on every node.
- `node-problem-detector` runs privileged with `hostPID: true` and mounts `/var/log`, `/dev/kmsg`, `/etc/localtime` — standard for NPD but worth noting for policy/PSP/PSA review.
- The observability namespace is **not** auto-deleted on `helm uninstall` to avoid ripping out cross-release resources; set `observability.createNamespace: false` if you manage it separately.
- Changing `observability.namespace` after install will orphan the existing cluster-scoped bindings. Uninstall and reinstall to rename.
