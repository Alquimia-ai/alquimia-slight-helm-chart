# Alquimia Slight

Helm chart scaffold and installation guide for **Alquimia Slight**, a product that is part of **Alquimia Vision**.

## Overview

Alquimia Slight is designed to be deployed on **appliances / edge nodes** and, in this first version, targets **RHEL 10 AI** environments.

The solution is composed of three main functional blocks:

- **Engine**
  - Application container
  - NATS broker
- **BFF**
  - Application container
  - PostgreSQL database
  - MinIO instance
- **VLM**
  - Vision-language model served with GPU support

## Target platform

This first version is intended for:

- **RHEL 10 AI**
- **k3s**
- **Longhorn**
- Appliance or node-based deployments
- Optional NVIDIA GPU support for the VLM component

## Prerequisites

Before installing the chart, make sure the target environment has the following:

### Mandatory

- A running **k3s** cluster
- **Longhorn** installed and working as the persistent storage backend
- Access to the required container images
- A Kubernetes namespace where the product will be deployed

### Required when VLM is enabled

- NVIDIA GPU available on the node
- NVIDIA drivers installed on the host
- NVIDIA container runtime configured
- NVIDIA device plugin deployed in the cluster
- Model files available locally on the appliance/node

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

## Installation

### 1. Update chart dependencies

```bash
helm dependency update ./alquimia-slight
```

### 2. Validate the chart

```bash
helm lint ./alquimia-slight
```

### 3. Render manifests

```bash
helm template alquimia-slight ./alquimia-slight -f ./alquimia-slight/values-rhel10-ai.yaml
```

### 4. Install or upgrade

```bash
helm upgrade --install alquimia-slight ./alquimia-slight \
  -n alquimia-slight \
  --create-namespace \
  -f ./alquimia-slight/values-rhel10-ai.yaml
```

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

### Internal services

By default, services should remain internal as `ClusterIP` unless there is a specific need to expose them externally.

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

- **RHEL 10 AI**
- **k3s**
- **Longhorn**
- optional **NVIDIA GPU**
- edge / appliance execution model

This structure provides a solid first version that is easy to install, operate, and evolve.
