# GHCR Server/Agent 分支設置指南

本文件說明如何為 telemetry 專案的 server 和 agent 分支設置 GitHub Container Registry (GHCR)。

## 📋 概述

專案現在支持三個分支的獨立鏡像構建：
- **main 分支** → `telemetry-webhook` (標籤: `webhook` 或 `latest`)
- **server 分支** → `telemetry-server` (標籤: `server`)
- **agent 分支** → `telemetry-agent` (標籤: `agent`)

## 🎯 主要功能

### 1. 自動刪除舊版本

當構建新版本時，GitHub Actions 會自動：
- 查找具有相同主標籤的舊版本（例如：`server`、`agent`、`latest`）
- 刪除舊版本，避免儲存空間浪費
- 保留帶有 SHA 或其他特殊標籤的版本作為歷史記錄

### 2. 分支特定的鏡像

- **server 分支** → 用於服務器端組件（Loki Server, Prometheus, Grafana 等）
- **agent 分支** → 用於代理端組件（Promtail, Zabbix Agent 等）

### 3. 自動構建觸發

當推送到對應分支時，會自動觸發構建：
- Push 到 `server` 分支 → 構建 `telemetry-server:server`
- Push 到 `agent` 分支 → 構建 `telemetry-agent:agent`
- Push 到 `main` 分支 → 構建 `telemetry-webhook:webhook`

## 🚀 快速開始

### 方法 1: 使用自動化腳本（推薦）

```bash
# 完整流程：刪除舊包 + 重建 server + 重建 agent
./scripts/setup-ghcr-branches.sh
```

腳本會引導您完成：
1. 刪除舊版本包
2. 重建 server 分支
3. 重建 agent 分支

### 方法 2: 手動操作

#### 步驟 1: 刪除舊包

```bash
# 使用刪除腳本
./scripts/delete-ghcr-package.sh

# 或直接使用 GitHub API
curl -X DELETE \
  -H "Authorization: token YOUR_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/user/packages/container/telemetry-webhook/versions/VERSION_ID"
```

#### 步驟 2: 重建 server 分支

```bash
# 使用重建腳本
./scripts/rebuild-branches-ghcr.sh
# 選擇選項 1（重建 server 分支）

# 或手動切換並觸發
git fetch origin server
git checkout origin/server -B server
git commit --allow-empty -m "Trigger GHCR build for server"
git push origin server
```

#### 步驟 3: 重建 agent 分支

```bash
# 使用重建腳本
./scripts/rebuild-branches-ghcr.sh
# 選擇選項 2（重建 agent 分支）

# 或手動切換並觸發
git fetch origin agent
git checkout origin/agent -B agent
git commit --allow-empty -m "Trigger GHCR build for agent"
git push origin agent
```

## 📦 鏡像標籤策略

### Server 分支 (`telemetry-server`)

- `server` - 最新構建（會自動替換舊的 `server` 標籤）
- `server-<sha>` - 基於 commit SHA
- `server-<run_number>` - 基於 GitHub Actions run number

### Agent 分支 (`telemetry-agent`)

- `agent` - 最新構建（會自動替換舊的 `agent` 標籤）
- `agent-<sha>` - 基於 commit SHA
- `agent-<run_number>` - 基於 GitHub Actions run number

### Main 分支 (`telemetry-webhook`)

- `latest` 或 `webhook` - 最新構建
- `webhook-<sha>` - 基於 commit SHA

## 🔧 使用鏡像

### 在 docker-compose.yml 中使用

#### Server 端

```yaml
webhook-service:
  image: ghcr.io/ikigai-kevin-k/telemetry-server:server
  container_name: kevin-telemetry-webhook
  network_mode: "host"
  restart: unless-stopped
```

#### Agent 端

```yaml
webhook-service:
  image: ghcr.io/ikigai-kevin-k/telemetry-agent:agent
  container_name: kevin-telemetry-webhook
  network_mode: "host"
  restart: unless-stopped
```

### 拉取鏡像

```bash
# 登入 GHCR（首次需要）
docker login ghcr.io -u ikigai-kevin-k

# 拉取 server 鏡像
docker pull ghcr.io/ikigai-kevin-k/telemetry-server:server

# 拉取 agent 鏡像
docker pull ghcr.io/ikigai-kevin-k/telemetry-agent:agent
```

## 📝 腳本說明

### 1. `scripts/delete-ghcr-package.sh`

用於刪除 GHCR 中的舊包版本。

**功能**：
- 列出所有版本
- 按標籤刪除指定版本
- 刪除所有版本

**使用**：
```bash
./scripts/delete-ghcr-package.sh
```

### 2. `scripts/rebuild-branches-ghcr.sh`

用於切換到指定分支並觸發 GHCR 構建。

**功能**：
- 切換到 server 分支並觸發構建
- 切換到 agent 分支並觸發構建
- 自動檢測並使用 GitHub CLI 或 API

**使用**：
```bash
./scripts/rebuild-branches-ghcr.sh
```

### 3. `scripts/setup-ghcr-branches.sh`

綜合腳本，整合刪除和重建流程。

**功能**：
- 刪除舊包
- 重建 server 分支
- 重建 agent 分支
- 可選擇單獨執行每個步驟

**使用**：
```bash
./scripts/setup-ghcr-branches.sh
```

## 🔄 自動化流程

### GitHub Actions Workflow

工作流程文件：`.github/workflows/build-and-push.yml`

**觸發條件**：
1. Push 到 `server`、`agent` 或 `main` 分支
2. Pull Request（僅構建，不推送）
3. 手動觸發（workflow_dispatch）

**執行步驟**：
1. **刪除舊版本** (`delete-old-versions` job)
   - 根據分支確定包名稱和標籤
   - 查找具有相同主標籤的舊版本
   - 刪除舊版本

2. **構建和推送** (`build-and-push` job)
   - 檢查對應分支
   - 構建 Docker 鏡像
   - 推送到 GHCR
   - 應用多個標籤（主標籤 + SHA + run number）

## ⚙️ 配置

### 環境變數

GitHub Actions 自動使用以下環境變數：
- `GITHUB_TOKEN` - 自動提供，無需配置
- `REGISTRY` - `ghcr.io`
- `OWNER` - `ikigai-kevin-k`

### 權限要求

確保 GitHub Actions 有以下權限：
- `contents: read` - 讀取代碼
- `packages: write` - 寫入包
- `delete: packages` - 刪除包版本

這些權限在 workflow 文件中已設置。

## 🔍 查看構建狀態

### GitHub Actions

```bash
# 查看所有 workflow 運行
https://github.com/ikigai-kevin-k/telemetry/actions
```

### 包管理頁面

- Server: https://github.com/ikigai-kevin-k/telemetry/pkgs/container/telemetry-server
- Agent: https://github.com/ikigai-kevin-k/telemetry/pkgs/container/telemetry-agent
- Webhook: https://github.com/ikigai-kevin-k/telemetry/pkgs/container/telemetry-webhook

## 🐛 疑難排解

### 1. 構建失敗

**問題**: Workflow 執行失敗

**解決方案**:
- 檢查 Actions 頁面的錯誤日誌
- 確認 Dockerfile.webhook 存在
- 確認 Dockerfile 語法正確
- 檢查分支是否有對應的文件

### 2. 舊版本未刪除

**問題**: 新版本構建後，舊版本仍在

**解決方案**:
- 檢查 `delete-old-versions` job 的日誌
- 確認標籤名稱匹配
- 手動運行刪除腳本

### 3. 權限錯誤

**問題**: `permission denied` 或 `unauthorized`

**解決方案**:
- 確認 workflow 權限設置正確
- 檢查 `GITHUB_TOKEN` 是否有足夠權限
- 確認包的可見性設置

### 4. 無法觸發 workflow

**問題**: Push 後 workflow 未觸發

**解決方案**:
- 檢查觸發路徑是否匹配（Dockerfile.webhook 等）
- 確認分支名稱正確（server/agent/main）
- 手動觸發 workflow_dispatch

## 📚 相關文檔

- [GitHub Container Registry 文檔](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)
- [GitHub Actions 文檔](https://docs.github.com/en/actions)
- [Docker 最佳實踐](https://docs.docker.com/develop/dev-best-practices/)

## 🆘 支援

如有問題：
1. 檢查本文件的疑難排解章節
2. 查看 GitHub Actions 運行日誌
3. 檢查包的設置和權限
4. 聯繫專案維護者

