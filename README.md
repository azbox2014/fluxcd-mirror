# k8s-mirror

一个用于从公共镜像仓库同步容器镜像到私有镜像仓库的项目，方便个人学习和实验使用。

## 项目概述

本项目主要用于将公共容器镜像仓库中的镜像同步到私有镜像仓库，确保私有仓库中的镜像保持最新状态。

## 功能特性

- **镜像同步**: 从公共仓库同步镜像到私有仓库
- **增量同步**: 仅同步新增的镜像标签
- **自动化执行**: 支持定时任务和手动触发
- **多种同步模式**: 支持有层级和无子层级同步

## 支持的镜像

本项目支持同步所有开源镜像，包括但不限于：

### 常用开源镜像类别
- **容器编排工具**: Kubernetes、Docker 相关镜像
- **CI/CD 工具**: Jenkins、GitLab Runner、ArgoCD 等
- **监控日志**: Prometheus、Grafana、Loki、Elasticsearch 等
- **数据库**: MySQL、PostgreSQL、Redis、MongoDB 等
- **消息队列**: Kafka、RabbitMQ、Redis 等
- **Web 服务器**: Nginx、Apache 等
- **编程语言**: Python、Node.js、Go、Java 等基础镜像

### 支持的主要镜像源
- **Docker Hub**: `docker.io/library/*`
- **GitHub Container Registry**: `ghcr.io/*`
- **Quay.io**: `quay.io/*`
- **Google Container Registry**: `gcr.io/*`
- **其他公共镜像仓库**

## 配置仓库 Secrets

在 GitHub 仓库的 Settings → Secrets and variables → Actions 中配置以下环境变量：

#### 必须配置的 Secrets

##### 有层级同步模式（推荐）
适用于需要保持镜像源结构的场景

| Secret 名称 | 说明 | 示例值 |
|------------|------|--------|
| `HIERARCHICAL_DOCKER_USER` | 有层级私有仓库用户名 | `your-username` |
| `HIERARCHICAL_DOCKER_TOKEN` | 有层级私有仓库访问令牌 | `your-token` |
| `HIERARCHICAL_PRIVATE_REGISTRY` | 有层级目标仓库地址 | `registry.cn-beijing.aliyuncs.com/your-namespace` |

##### 无子层级同步模式
适用于简化的镜像组织结构

| Secret 名称 | 说明 | 示例值 |
|------------|------|--------|
| `FLAT_DOCKER_USER` | 无层级私有仓库用户名 | `flat-username` |
| `FLAT_DOCKER_TOKEN` | 无层级私有仓库访问令牌 | `flat-token` |
| `FLAT_PRIVATE_REGISTRY` | 无层级目标仓库地址 | `registry.cn-hangzhou.aliyuncs.com/flat-namespace` |

**说明**: 所有开源镜像均无需额外认证，可直接同步公有镜像。

### 同步方式

#### 手动同步（推荐使用）

本项目支持手动同步任意公共镜像到私有仓库：

1. **访问 GitHub Actions 页面**
   - 进入仓库的 Actions 页面
   - 选择 "Sync Docker Images to Private Registry (Flat Sync)" 工作流

2. **触发同步**
   - 点击 "Run workflow" 按钮
   - 在输入框中填写要同步的镜像地址
   - 示例：`docker.io/golang:1.26.2-bookworm`

3. **完成同步**
   - 点击 "Run workflow" 开始同步
   - 等待工作流执行完成
   - 检查执行日志确认同步成功

**支持的镜像格式示例：**
- `docker.io/golang:1.26.2-bookworm`
- `ghcr.io/fluxcd/helm-controller:v1.0.0`
- `quay.io/prometheus/prometheus:latest`
- `registry.k8s.io/pause:3.9`

#### 自动同步
- 支持通过定时任务自动执行镜像同步（如有需要可配置）

## 技术实现

使用 skopeo 工具进行镜像同步，通过检测源镜像标签并进行差异比对，实现增量同步。