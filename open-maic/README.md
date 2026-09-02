# OpenMAIC

Docker image build configuration for [OpenMAIC](https://github.com/THU-MAIC/OpenMAIC).

## Registries

| Registry | Image |
|----------|-------|
| GHCR | `ghcr.io/<owner>/openmaic` |
| Docker Hub | `<username>/openmaic` |
| ACR | `registry.cn-hangzhou.aliyuncs.com/osc-org/openmaic` |
| QCR | `<qcr-registry>/osc-org/openmaic` |

## Build Args

| Arg | Description |
|-----|-------------|
| `NEXT_PUBLIC_PERSISTENCE` | Enable persistence |
| `NEXT_PUBLIC_PRO_WORKBENCH_ENABLED` | Enable pro workbench |
| `OPENMAIC_AGENT_RUNTIME_ENABLED` | Enable agent runtime |
| `NEXT_PUBLIC_MAIC_EDITOR_ENABLED` | Enable MAIC editor |
| `NEXT_PUBLIC_MAIC_EDITOR_RENDERER_ENABLED` | Enable MAIC editor renderer |
| `NEXT_PUBLIC_MAIC_PLAYBACK_RENDERER_ENABLED` | Enable MAIC playback renderer |

## Manual Build

Trigger workflow manually with optional VERSION input (e.g., `v1.0.0`).

## Schedule

Daily build at 02:00 UTC (10:00 Beijing time).
