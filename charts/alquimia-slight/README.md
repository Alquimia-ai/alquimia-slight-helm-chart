# Alquimia Slight

Helm chart scaffold and installation guide for **Alquimia Slight**, a product that is part of **Alquimia Vision**.

## Overview

Alquimia Slight is designed to be deployed on **appliances / edge nodes**. Typical targets are **RHEL 10 AI** or **Ubuntu LTS**; use the bundled values files to match the OS profile. Both profiles ship the full stack including the GPU-backed VLM.

The solution is composed of these main functional blocks:

- **Engine**
  - Application container
  - NATS broker
- **BFF**
  - Application container
  - PostgreSQL database
  - MinIO instance
- **Web**
  - Frontend (Vite) served as static assets
  - Configurable service exposure (`ClusterIP` or `NodePort`)
- **MediaMTX**
  - RTSP / HLS / WebRTC streaming and recording
  - Optional dedicated namespace (default `media`)
  - HTTP authentication delegated to the BFF
- **VLM (`model`)**
  - Vision-language model served with vLLM and GPU support
  - Model stored on a PVC (Longhorn by default)
  - Optional Helm hook Job that pulls the model from Hugging Face into the PVC on install/upgrade

## Target platform

This first version is intended for:

- **RHEL 10 AI** (see `values-rhel10-ai.yaml`) or **Ubuntu LTS** (see `values-ubuntu.yaml`)
- **k3s**
- **Longhorn**
- Appliance or node-based deployments
- NVIDIA GPU + runtime class `nvidia` for the VLM workload

## Prerequisites

Before installing the chart, make sure the target environment has the following:

### Mandatory

- A running **k3s** cluster
- **Longhorn** installed and working as the persistent storage backend
- Access to the required container images
- A Kubernetes namespace where the product will be deployed
- For **private** registries: a pull Secret in the **`alquimia-slight`** namespace (see [Private container registry (important)](#private-container-registry-important))

### Required when VLM is enabled

- NVIDIA GPU available on the node
- NVIDIA drivers installed on the host
- NVIDIA container runtime configured
- NVIDIA device plugin deployed in the cluster
- Either outbound internet access from the cluster (so the downloader Job can fetch the model from Hugging Face) or a pre-populated PVC (see `model.persistence.existingClaim`)

## Private container registry (important)

If you use a **private** container registry, create a **pull Secret** in the **`alquimia-slight`** namespace. This chart does not create registry credentials in Git. Reference the Secret name in `global.imagePullSecrets` (default: `regcred` in `values.yaml`).

```bash
kubectl create secret docker-registry regcred \
  --docker-server=<registry-hostname> \
  --docker-username=<username> \
  --docker-password=<token-or-password> \
  -n alquimia-slight
```

If you use a different Secret name, update `global.imagePullSecrets` accordingly.

## Components

### Engine

The Engine component includes:

- Engine container
- Internal configuration via ConfigMap
- ClusterIP Service
- Connection to BFF
- Connection to NATS

### BFF

The BFF component includes:

- BFF container
- Internal configuration via ConfigMap
- Sensitive values stored in Secret
- ClusterIP Service
- Connection to:
  - Engine
  - PostgreSQL
  - MinIO
  - NATS

### PostgreSQL

The PostgreSQL component provides:

- Internal database for the BFF
- Persistent storage through PVC
- Secret-based credentials

### MinIO

The MinIO component provides:

- S3-compatible object storage
- Persistent storage through PVC
- Internal service for API and console
- Credentials managed through Secret

### VLM (`model`)

The VLM component provides:

- vLLM-based OpenAI-compatible model serving
- GPU runtime support via `runtimeClassName: nvidia`
- Model snapshot stored on a dedicated PVC, mounted at `model.mountPath` (default `/models`). The PVC is annotated with `helm.sh/resource-policy: keep` so the downloaded weights survive `helm uninstall`.
- Optional **model downloader Job** (`model.downloader.enabled`, default `true`) that runs as a `post-install` / `post-upgrade` Helm hook and pulls the model from Hugging Face into the PVC using `huggingface_hub.snapshot_download`. The Job is idempotent (skips the download when `config.json` already exists) and supports gated/private repos via `model.downloader.hfToken` (or an existing secret via `model.downloader.existingSecret`).
- An `initContainer` in the Deployment blocks vLLM startup until the model files are ready on the PVC.
- The flags `--model` and `--served-model-name` are injected automatically from `model.servedName` / `model.localDir`; only additional flags go into `model.extraArgs`.

### Web

The Web component provides:

- Frontend container (`argos-web`)
- Configuration via ConfigMap keys exposed as **container environment variables** (`envFrom` on the Deployment): `VITE_*` and MediaMTX-related hints for the runtime.
- Optional **`global.host`**: when set and the matching `web.config` fields are empty, the chart fills `VITE_BFF_URL` and WebRTC-related values from the public host plus BFF/web `NodePort` values (Helm-rendered ConfigMap only).
- Service type `ClusterIP` (internal only) or `NodePort` (optional fixed `nodePort`)

### MediaMTX

The MediaMTX component provides:

- MediaMTX container with recording under `/recordings` (PVC or `emptyDir` when persistence is disabled)
- Optional `Namespace` resource (`mediamtx.createNamespace`) and configurable target namespace (`mediamtx.namespace`, default `media`)
- `hostNetwork` and `dnsPolicy: ClusterFirstWithHostNet` suitable for appliance / edge setups
- `MTX_AUTHHTTPADDRESS` built automatically to reach the BFF at `/internal/media/auth`, unless overridden with `mediamtx.auth.httpAddress`
- Multi-port `Service` (`NodePort` by default; `nodePort` values are omitted when `service.type` is not `NodePort`)

### Observability (optional)

Self-contained telemetry stack in its own namespace, disabled by default. Bundles an **OTel Collector** DaemonSet (also exposed as a `Service`), **kube-state-metrics** and **node-problem-detector**. When enabled, `bff`, `engine` and `web` pods are automatically wired to ship OTLP/HTTP to the internal collector (overridable to hit an external backend directly). Supports both on-premise (no auth) and cloud (Grafana Cloud or similar, via Secret) export targets.

See [`docs/observability.md`](../../docs/observability.md) for the full architecture, modes and values reference.

## Example values

### Global

```yaml
global:
  storageClass: longhorn
  host: "192.168.77.143"
  imagePullSecrets:
    - regcred
```

### Product metadata

```yaml
product:
  name: "Alquimia Slight"
  suite: "Alquimia Vision"
  targetPlatform: "appliance"
  os: "RHEL 10 AI"
```

### Engine

```yaml
engine:
  enabled: true
  replicaCount: 1
  image:
    repository: alquimiaai/argos-engine
    tag: engine-v0.3.0
    pullPolicy: IfNotPresent
  service:
    type: ClusterIP
    port: 8000
```

### BFF

```yaml
bff:
  enabled: true
  replicaCount: 1
  image:
    repository: alquimiaai/argos-bff
    tag: bff-v0.8.0-beta.0
    pullPolicy: IfNotPresent
```

### PostgreSQL

```yaml
postgres:
  enabled: true
  persistence:
    enabled: true
    size: 10Gi
    storageClass: longhorn
```

### MinIO

```yaml
minio:
  enabled: true
  persistence:
    enabled: true
    size: 20Gi
    storageClass: longhorn
```

### VLM (`model`)

Minimal override (Hugging Face model, Longhorn-backed PVC, auto-download):

```yaml
model:
  enabled: true
  runtimeClassName: nvidia
  servedName: "Qwen/Qwen3-VL-8B-Instruct"
  persistence:
    size: 50Gi
    # storageClass: ""  # empty -> falls back to global.storageClass (longhorn)
  downloader:
    enabled: true
    # hfToken: "hf_xxx"  # only for gated/private repos
```

Switching to a different HF model only requires changing `model.servedName`; the
values used for `--model`, `--served-model-name`, the downloader target, and
the init container are all derived from it. Leave `model.localDir` empty to
derive the subdirectory automatically (e.g. `qwen-qwen3-vl-8b-instruct`).

To reuse an externally-populated PVC, skip the downloader and point to the
existing claim:

```yaml
model:
  downloader:
    enabled: false
  persistence:
    existingClaim: my-preloaded-models-pvc
```

### Web

```yaml
web:
  enabled: true
  image:
    repository: alquimiaai/argos-web
    tag: web-v0.6.1-beta.0
  service:
    type: NodePort
    port: 8080
    targetPort: 80
    nodePort: 31000
  config:
    viteAppTimeZone: "America/Argentina/Buenos_Aires"
    viteBffUrl: "http://<bff-host-or-ip>:<bff-nodeport>"
```

Use `service.type: ClusterIP` and omit `nodePort` when the UI is only reached via Ingress, port-forward, or in-cluster clients.

### MediaMTX

```yaml
mediamtx:
  enabled: true
  createNamespace: true
  namespace: media
  persistence:
    enabled: true
    size: 20Gi
    storageClass: longhorn
  auth:
    httpAddress: ""
    bffNamespace: ""
    path: /internal/media/auth
  hostNetwork: true
  dnsPolicy: ClusterFirstWithHostNet
  service:
    type: NodePort
```

If the BFF runs in a different namespace than the Helm release, set `mediamtx.auth.bffNamespace` to that namespace. If the in-cluster BFF Service name does not match `<release>-bff`, set `mediamtx.auth.httpAddress` to the full URL (for example `http://argos-bff.bff.svc.cluster.local:8000/internal/media/auth`).

### Environment profiles

Both bundled profiles ship the same full stack (GPU-backed VLM included); they
only differ in OS metadata and environment-specific secrets. They also document
**`global.host`**: set this manually to the IP or hostname clients use in the
browser (Helm cannot infer it), or leave it empty and set `web.config` URLs
explicitly.

- `values-rhel10-ai.yaml`: `product.os: "RHEL 10 AI"`, BFF bootstrap admin and
  DB/MinIO credentials, Longhorn-backed PostgreSQL/MinIO persistence.
- `values-ubuntu.yaml`: `product.os: "Ubuntu 22.04 LTS"`, sets `global.host`
  to the appliance IP, same credentials structure. Assumes NVIDIA drivers and
  runtime class are already configured on the host.

To disable the VLM workload (for example for a CPU-only test), override
explicitly:

```yaml
model:
  enabled: false
```

## Installation

### 1. Update chart dependencies

```bash
helm dependency update ./charts/alquimia-slight
```

### 2. Validate the chart

```bash
helm lint ./charts/alquimia-slight
```

### 3. Render manifests

RHEL 10 AI:

```bash
helm template alquimia-slight ./charts/alquimia-slight -f ./charts/alquimia-slight/values-rhel10-ai.yaml
```

Ubuntu LTS:

```bash
helm template alquimia-slight ./charts/alquimia-slight -f ./charts/alquimia-slight/values-ubuntu.yaml
```

### 4. Install or upgrade

RHEL 10 AI:

```bash
helm upgrade --install alquimia-slight ./charts/alquimia-slight \
  -n alquimia-slight \
  --create-namespace \
  -f ./charts/alquimia-slight/values-rhel10-ai.yaml
```

Ubuntu LTS:

```bash
helm upgrade --install alquimia-slight ./charts/alquimia-slight \
  -n alquimia-slight \
  --create-namespace \
  -f ./charts/alquimia-slight/values-ubuntu.yaml
```

## Use published chart repository

Public Helm repository URL:

`https://alquimia-ai.github.io/alquimia-slight-helm-chart`

```bash
helm repo add alquimia-slight https://alquimia-ai.github.io/alquimia-slight-helm-chart
helm repo update
helm search repo alquimia-slight
helm install alquimia-slight alquimia-slight/alquimia-slight -n alquimia-slight --create-namespace -f ./charts/alquimia-slight/values-ubuntu.yaml
```

## Operational notes

### NVIDIA device plugin

The NVIDIA device plugin should be managed as a **cluster prerequisite**, not as part of the application chart.

### Model storage

When `model.enabled=true`, the chart creates a dedicated PVC (or reuses the one
passed via `model.persistence.existingClaim`) and the Helm hook Job downloads
the repo `model.servedName` from Hugging Face into it. The Job:

- Runs as `post-install,post-upgrade` and is recreated on each upgrade (`helm.sh/hook-delete-policy: before-hook-creation`).
- Skips the download when `config.json` is already present in the target directory.
- Uses `hf_transfer` for faster downloads (toggle with `model.downloader.useHfTransfer`).
- Accepts an optional `HF_TOKEN` for gated or private repos via `model.downloader.hfToken` or an existing secret (`model.downloader.existingSecret`, key `HF_TOKEN`).

The PVC carries `helm.sh/resource-policy: keep`, so `helm uninstall` does not
delete the downloaded weights.

### Persistence

The following components use persistent storage:

- PostgreSQL
- MinIO
- MediaMTX (recordings PVC), when `mediamtx.persistence.enabled` is true
- VLM model weights (`<release>-vlm-models` PVC)

### Internal services

**BFF** and **MinIO** default to `NodePort` so browser clients can reach the API and S3-compatible endpoints from outside the cluster; tune `bff.service.nodePort` and `minio.service.nodePortApi` / `nodePortConsole` in `values.yaml`. Other backends (Engine, PostgreSQL, VLM) stay `ClusterIP`. The **Web** and **MediaMTX** components also support `NodePort`; align `web.config` (`viteBffUrl`, etc.) and MediaMTX WebRTC env vars with the URLs and ports you publish.

### Namespaces

Most chart resources are installed in the **Helm release namespace** (`helm upgrade --install ... -n <ns>`). **MediaMTX** can optionally deploy into a separate namespace (`mediamtx.namespace`, default `media`) and create that namespace when `mediamtx.createNamespace` is true. The BFF URL used for MediaMTX authentication still defaults to `<release>-bff.<release-namespace>.svc.cluster.local` unless you override `mediamtx.auth.*`.

## Recommended future improvements

As the product evolves, consider adding:

- support for external PostgreSQL
- support for external MinIO / S3
- optional Ingress
- healthcheck tuning
- resource profiles by appliance size
- node affinity for GPU scheduling
- dedicated values files per environment

## Summary

Alquimia Slight is a Helm-packaged appliance-oriented deployment for Alquimia Vision, designed for:

- **RHEL 10 AI** or **Ubuntu LTS** (both profiles ship the full stack, VLM included)
- **k3s**
- **Longhorn**
- **NVIDIA GPU** for the VLM workload
- **Web** UI and **MediaMTX** streaming where required
- edge / appliance execution model

This structure provides a solid first version that is easy to install, operate, and evolve.
