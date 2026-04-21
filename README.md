# Alquimia Slight Helm Chart

Helm chart repository for **Alquimia Slight**, an appliance/edge deployment of the **Alquimia Vision** product suite.

The stack bundles:

- **Engine** (+ NATS broker)
- **BFF** (+ PostgreSQL + MinIO)
- **Web** UI
- **MediaMTX** (RTSP / HLS / WebRTC streaming and recording)
- **VLM** — vLLM-based vision-language model serving on GPU, with an optional Helm hook Job that pulls the model from Hugging Face into a PVC on install/upgrade

Target platform: **RHEL 10 AI** or **Ubuntu LTS** running on **k3s** with **Longhorn** persistence and an optional **NVIDIA GPU**.

## Repository layout

```
charts/
  alquimia-slight/       # The Helm chart (full docs in its own README)
    Chart.yaml
    values.yaml
    values-rhel10-ai.yaml
    values-ubuntu.yaml
    templates/
    README.md            # <-- full installation and values reference
.github/workflows/       # Chart release automation (chart-releaser)
artifacthub-repo.yml     # Artifact Hub metadata
```

See [`charts/alquimia-slight/README.md`](charts/alquimia-slight/README.md) for the full installation guide, component reference, values examples, and operational notes.

## Quick start

Add the public Helm repository and install:

```bash
helm repo add alquimia-slight https://alquimia-ai.github.io/alquimia-slight-helm-chart
helm repo update

# RHEL 10 AI appliance
helm upgrade --install alquimia-slight alquimia-slight/alquimia-slight \
  -n alquimia-slight --create-namespace \
  -f ./charts/alquimia-slight/values-rhel10-ai.yaml

# Ubuntu LTS appliance
helm upgrade --install alquimia-slight alquimia-slight/alquimia-slight \
  -n alquimia-slight --create-namespace \
  -f ./charts/alquimia-slight/values-ubuntu.yaml
```

Or install directly from this repository:

```bash
helm dependency update ./charts/alquimia-slight
helm upgrade --install alquimia-slight ./charts/alquimia-slight \
  -n alquimia-slight --create-namespace \
  -f ./charts/alquimia-slight/values-rhel10-ai.yaml
```

## Changing the served model

The chart is wired so that changing a single value switches the served model end-to-end (vLLM flags, download target on the PVC, init container wait path):

```yaml
model:
  servedName: "Qwen/Qwen3-VL-8B-Instruct"   # single source of truth
  downloader:
    enabled: true
    # hfToken: "hf_xxx"                     # only for gated/private repos
```

Full details in the [chart README](charts/alquimia-slight/README.md).

## Contributing

Releases are cut automatically from `main` via the workflow under `.github/workflows/release-chart.yml`. Bump `charts/alquimia-slight/Chart.yaml` (`version` and/or `appVersion`) and merge to `main` to publish a new chart version to the GitHub Pages–hosted Helm repo.

## Links

- Chart documentation: [`charts/alquimia-slight/README.md`](charts/alquimia-slight/README.md)
- Helm repository: https://alquimia-ai.github.io/alquimia-slight-helm-chart
- Project home: https://alquimia.ai
