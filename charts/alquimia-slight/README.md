# Alquimia Slight

Helm chart scaffold and installation guide for **Alquimia Slight**, a product that is part of **Alquimia Vision**.

## Overview

Alquimia Slight is designed to be deployed on **appliances / edge nodes**. Typical targets are **RHEL 10 AI** or **Ubuntu LTS**; use the bundled values files to match the OS profile and optional VLM.

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
- **VLM**
  - Vision-language model served with GPU support

## Target platform

This first version is intended for:

- **RHEL 10 AI** (see `values-rhel10-ai.yaml`) or **Ubuntu LTS** (see `values-ubuntu.yaml`, VLM disabled)
- **k3s**
- **Longhorn**
- Appliance or node-based deployments
- Optional NVIDIA GPU support for the VLM component (not used in the Ubuntu profile)

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
- Model files available locally on the appliance/node

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

### VLM

The VLM component provides:

- vLLM-based model serving
- GPU runtime support
- Local model mount through `hostPath`
- Offline model usage for appliance scenarios

### Web

The Web component provides:

- Frontend container (`argos-web`)
- Configuration via ConfigMap keys exposed as **container environment variables** (`envFrom` on the Deployment): `VITE_*` and MediaMTX-related hints for the runtime.
- Optional **`web.externalHost`**: when set and the matching `web.config` fields are empty, the chart fills `VITE_BFF_URL` and WebRTC-related values from the public host plus BFF/web `NodePort` values (Helm-rendered ConfigMap only).
- Service type `ClusterIP` (internal only) or `NodePort` (optional fixed `nodePort`)

### MediaMTX

The MediaMTX component provides:

- MediaMTX container with recording under `/recordings` (PVC or `emptyDir` when persistence is disabled)
- Optional `Namespace` resource (`mediamtx.createNamespace`) and configurable target namespace (`mediamtx.namespace`, default `media`)
- `hostNetwork` and `dnsPolicy: ClusterFirstWithHostNet` suitable for appliance / edge setups
- `MTX_AUTHHTTPADDRESS` built automatically to reach the BFF at `/internal/media/auth`, unless overridden with `mediamtx.auth.httpAddress`
- Multi-port `Service` (`NodePort` by default; `nodePort` values are omitted when `service.type` is not `NodePort`)

## Example values

### Global

```yaml
global:
  storageClass: longhorn
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

### VLM

```yaml
vlm:
  enabled: true
  runtimeClassName: nvidia
  model:
    hostPath: /var/home/alquimia/models
    path: /models/qwen3-vl-8b
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

### Ubuntu (VLM off)

Use `values-ubuntu.yaml` for an Ubuntu-oriented deployment **without** the VLM workload (`vlm.enabled: false`). It sets `product.os` and pins PostgreSQL/MinIO persistence to Longhorn, same style as `values-rhel10-ai.yaml` but without GPU/model settings. It also documents **`web.externalHost`**: set this manually to the IP or hostname clients use in the browser (Helm cannot infer it), or leave it empty and set `web.config` URLs explicitly.

```yaml
# See values-ubuntu.yaml — key override:
vlm:
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

RHEL / VLM on:

```bash
helm template alquimia-slight ./charts/alquimia-slight -f ./charts/alquimia-slight/values-rhel10-ai.yaml
```

Ubuntu / VLM off:

```bash
helm template alquimia-slight ./charts/alquimia-slight -f ./charts/alquimia-slight/values-ubuntu.yaml
```

### 4. Install or upgrade

RHEL / VLM on:

```bash
helm upgrade --install alquimia-slight ./charts/alquimia-slight \
  -n alquimia-slight \
  --create-namespace \
  -f ./charts/alquimia-slight/values-rhel10-ai.yaml
```

Ubuntu / VLM off:

```bash
helm upgrade --install alquimia-slight ./charts/alquimia-slight \
  -n alquimia-slight \
  --create-namespace \
  -f ./charts/alquimia-slight/values-ubuntu.yaml
```

## Artifact Hub publication

This repository includes a GitHub Actions workflow (`.github/workflows/release-chart.yml`) that automatically:

- packages the Helm chart
- uploads chart archives to GitHub Releases
- updates `index.yaml` on the `gh-pages` branch

One-time setup:

1. In GitHub, enable **Pages** from branch `gh-pages` (root).
2. In Artifact Hub, add this Helm repository URL:
   `https://<github-user-or-org>.github.io/alquimia-slight-helm-chart`
3. Artifact Hub gives you a repository ID. Replace
   `repositoryID` in `artifacthub-repo.yml` and commit.

After that, every push to `main` that changes chart files will republish automatically.

## Operational notes

### NVIDIA device plugin

The NVIDIA device plugin should be managed as a **cluster prerequisite**, not as part of the application chart.

### Local model path

If `vlm.enabled=true`, the model files must exist on the appliance/node under the configured host path, for example:

```bash
/var/home/alquimia/models
```

### Persistence

The following components should use persistent storage:

- PostgreSQL
- MinIO
- MediaMTX (recordings PVC), when `mediamtx.persistence.enabled` is true

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

- **RHEL 10 AI** or **Ubuntu LTS** (profile without VLM via `values-ubuntu.yaml`)
- **k3s**
- **Longhorn**
- optional **NVIDIA GPU** (VLM; omitted on the Ubuntu profile)
- **Web** UI and **MediaMTX** streaming where required
- edge / appliance execution model

This structure provides a solid first version that is easy to install, operate, and evolve.
