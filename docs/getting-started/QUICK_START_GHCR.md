# GHCR 快速開始指南

## 🚀 立即執行

### 完整自動化流程（推薦）

```bash
# 執行完整設置：刪除舊包 + 重建 server + 重建 agent
./scripts/setup-ghcr-branches.sh
```

選擇選項 **6**（完整流程），腳本會自動：
1. 刪除舊版本的 `telemetry-webhook` 包
2. 切換到 `origin/server` 分支並觸發構建
3. 切換到 `origin/agent` 分支並觸發構建

### 分步驟執行

#### 步驟 1: 刪除舊包

```bash
./scripts/delete-ghcr-package.sh
```

選擇 **3**（刪除所有版本）來清理舊的 `telemetry-webhook` 包。

#### 步驟 2: 重建 server 分支

```bash
./scripts/rebuild-branches-ghcr.sh
```

選擇 **1**（重建 server 分支）。

#### 步驟 3: 重建 agent 分支

```bash
./scripts/rebuild-branches-ghcr.sh
```

選擇 **2**（重建 agent 分支）。

## 📦 構建結果

構建完成後，您將得到：

- **Server 分支** → `ghcr.io/ikigai-kevin-k/telemetry-server:server`
- **Agent 分支** → `ghcr.io/ikigai-kevin-k/telemetry-agent:agent`

## 🔍 查看構建狀態

- **Actions**: https://github.com/ikigai-kevin-k/telemetry/actions
- **Server 包**: https://github.com/ikigai-kevin-k/telemetry/pkgs/container/telemetry-server
- **Agent 包**: https://github.com/ikigai-kevin-k/telemetry/pkgs/container/telemetry-agent

## ⚙️ 自動替換舊版本

GitHub Actions workflow 會在每次構建時：
1. **自動刪除**具有相同主標籤的舊版本（`server`、`agent`、`latest`）
2. **推送新版本**並應用相同的標籤
3. **保留**帶有 SHA 或其他標籤的歷史版本

## 📝 詳細文檔

- [GHCR Branch Setup](GHCR_BRANCH_SETUP.md) - 完整設置指南
- [GHCR Setup](GHCR_SETUP.md) - 基本使用說明

