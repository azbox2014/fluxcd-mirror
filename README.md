# OCI Tools

多个独立的子项目，共享同一仓库。

## 目录结构

```
├── mirror/       OCI 镜像同步工具，将公共镜像同步到私有仓库
├── derper/       Tailscale DERP 中继服务器 Docker 镜像
├── webhook/      adnanh/webhook Docker 镜像
├── code-server/  code-server 开发工具箱 Docker 镜像
├── zerotier/     ZeroTier One Docker 镜像
├── open-maic/    OpenMAIC Docker 镜像
```

## mirror/

从 Docker Hub、GHCR、Quay.io 等公共仓库同步容器镜像到阿里云、腾讯云等私有仓库。支持层级、扁平、QCR 三种同步模式，通过 GitHub Actions 定时或手动触发。

详见 [mirror/README.md](mirror/README.md)

## derper/

[Tailscale DERP](https://tailscale.com/kb/1118/custom-derp-servers/) 服务器的 Docker 打包。支持多架构构建（amd64/arm64），自动跟踪上游 Tailscale 版本。

详见 [derper/README.md](derper/README.md)

## webhook/

[adnanh/webhook](https://github.com/adnanh/webhook/) 的 Docker 打包，扩展了 curl、bash、jq 工具。支持多架构构建（386/amd64/arm/arm64），自动跟踪上游版本。

详见 [webhook/README.md](webhook/README.md)

## code-server/

基于 [linuxserver/code-server](https://github.com/linuxserver/docker-code-server) 的开发工具箱，集成了 kubectl、Helm、Flux、Docker CLI/Buildx、skopeo、Oh My Zsh + powerlevel10k 等工具。支持多架构构建（amd64/arm64），自动跟踪上游版本。

详见 [code-server/Dockerfile](code-server/Dockerfile)

## zerotier/

[ZeroTier One](https://www.zerotier.com/) 的 Docker 打包。支持多架构构建（amd64/arm64），自动跟踪上游版本标签。

详见 [zerotier/README.md](zerotier/README.md)

## open-maic/

[OpenMAIC](https://github.com/THU-MAIC/OpenMAIC) 的 Docker 打包。支持多架构构建（amd64/arm64），自动跟踪上游版本标签。多仓库推送：GHCR、Docker Hub、ACR、QCR。

> **注意**：该镜像仅用于私有网络下的集群部署与实验，不要对外提供服务。

详见 [open-maic/README.md](open-maic/README.md)
