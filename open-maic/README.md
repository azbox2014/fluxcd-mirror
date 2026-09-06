# OpenMAIC

Docker image build configuration for [OpenMAIC](https://github.com/THU-MAIC/OpenMAIC).

> [!WARNING]
> **私有网络专用 / Private network only.**
> 本镜像仅用于内网集群部署与实验用途，**不要对外提供服务**。
> This image is built for trusted private-network cluster deployments and
> experimentation only. **Do not expose it to the public internet.**
>
> 原因：镜像烘入了固定的 `NEXT_PUBLIC_PERSISTENCE_TOKEN`（见下），该值会编译进
> 公开的浏览器 bundle，任何访客都能提取它并伪造 `x-learner-key`，从而读写**全部**
> 学习者数据。上游明确将该机制定位为开发用途，不提供任何用户隔离。

## Registries

| Registry | Image |
|----------|-------|
| GHCR | `ghcr.io/<owner>/openmaic` |
| Docker Hub | `<username>/openmaic` |
| ACR | `registry.cn-hangzhou.aliyuncs.com/osc-org/openmaic` |
| QCR | `<qcr-registry>/osc-org/openmaic` |

## Build Args

| Arg | Value | Description |
|-----|-------|-------------|
| `NEXT_PUBLIC_PERSISTENCE` | `1` | Enable persistence |
| `NEXT_PUBLIC_PERSISTENCE_TOKEN` | `openmaic-internal` | Browser-side persistence token, see below |
| `NEXT_PUBLIC_PRO_WORKBENCH_ENABLED` | `true` | Enable pro workbench |
| `OPENMAIC_AGENT_RUNTIME_ENABLED` | `true` | Enable agent runtime |
| `NEXT_PUBLIC_MAIC_EDITOR_ENABLED` | `true` | Enable MAIC editor |
| `NEXT_PUBLIC_MAIC_EDITOR_RENDERER_ENABLED` | `true` | Enable MAIC editor renderer |
| `NEXT_PUBLIC_MAIC_PLAYBACK_RENDERER_ENABLED` | `true` | Enable MAIC playback renderer |

### `NEXT_PUBLIC_PERSISTENCE_TOKEN`

固定值 `openmaic-internal`，**必须**通过 build arg 传入。

上游 `lib/persistence/bootstrap.ts` 在浏览器侧读取该变量，作为访问
`/api/persistence/*` 的 `Authorization: Bearer` 头。它经 `Dockerfile` 的
`ARG` → `ENV` 由 Next.js 在 `pnpm build` 时**内联进浏览器 bundle**，因此：

- 运行时通过环境变量、ConfigMap、Secret 注入**一律无效**
- 缺失该 build arg 时，bundle 中该值为 `undefined`，浏览器不发送 authorization
  头，服务端 `lib/persistence/server-auth.ts` 一律返回 401，持久化完全不可用

部署时必须将运行时的 `PERSISTENCE_DEV_TOKEN` 设为**完全相同**的值，服务端才能
通过比对。

该 token 并非密钥 —— 上游在 `server-auth.ts` 中明确说明它会公开在浏览器 bundle
中，唯一作用是把无关的网络扫描器挡在可信网络的端点之外。因此将其固化进镜像不构成
额外的泄露风险，但也正因如此，本镜像只适用于可信内网。

## Runtime Notes

OpenMAIC v1.0.1 收紧了两处默认行为，内网部署需要在**运行时**（ConfigMap 等）显式
opt-in，不应烘入镜像：

| Env | Why |
|-----|-----|
| `PERSISTENCE_ALLOW_INSECURE_DEV_AUTH=true` | v1.0.1 起 `NODE_ENV=production` 下拒绝开发用持久化认证器，可信网络部署需显式接受该取舍 |
| `ALLOW_LOCAL_NETWORKS=true` | v1.0.1 起出站 URL 守卫在所有环境生效并逐跳校验重定向；若域名解析到内网 IP，不设此项会被拦截 |

这两项属于部署环境属性而非镜像属性，烘入镜像会给所有拉取者默认关闭安全防护。

## Manual Build

Trigger workflow manually with optional VERSION input (e.g., `v1.0.0`).

## Schedule

Daily build at 02:00 UTC (10:00 Beijing time).
