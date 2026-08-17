# OCI Tools

两个独立的子项目，共享同一仓库。

## 目录结构

```
├── mirror/       OCI 镜像同步工具，将公共镜像同步到私有仓库
├── derper/       Tailscale DERP 中继服务器 Docker 镜像
```

## mirror/

从 Docker Hub、GHCR、Quay.io 等公共仓库同步容器镜像到阿里云、腾讯云等私有仓库。支持层级、扁平、QCR 三种同步模式，通过 GitHub Actions 定时或手动触发。

详见 [mirror/README.md](mirror/README.md)

## derper/

[Tailscale DERP](https://tailscale.com/kb/1118/custom-derp-servers/) 服务器的 Docker 打包。支持多架构构建（amd64/arm64），自动跟踪上游 Tailscale 版本。

详见 [derper/README.md](derper/README.md)
