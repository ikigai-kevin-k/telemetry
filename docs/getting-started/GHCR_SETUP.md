# GitHub Container Registry (GHCR) 設置指南

本文件說明如何為 telemetry 專案設置和使用 GitHub Container Registry (GHCR)。

## 📋 目錄

- [概述](#概述)
- [自動化構建流程](#自動化構建流程)
- [手動構建和推送](#手動構建和推送)
- [使用 GHCR 鏡像](#使用-ghcr-鏡像)
- [權限設置](#權限設置)
- [疑難排解](#疑難排解)

## 概述

GitHub Container Registry (GHCR) 是 GitHub 提供的容器鏡像存儲服務，與 GitHub Actions 深度整合，可以自動化構建和推送 Docker 鏡像。

### 當前項目中的容器鏡像

- **telemetry-webhook**: Grafana Webhook 服務（自定義構建）
  - 鏡像位置: `ghcr.io/ikigai-kevin-k/telemetry-webhook`
  - Dockerfile: `Dockerfile.webhook`

## 自動化構建流程

### GitHub Actions Workflow

專案包含 `.github/workflows/build-and-push.yml`，會在以下情況自動觸發：

1. **Push 到 main 分支**
   - 當 `Dockerfile.webhook` 或 `grafana_webhook_service.py` 有變更時
   
2. **Pull Request**
   - 構建鏡像但不推送（用於驗證）

3. **手動觸發**
   - 在 GitHub Actions 頁面手動執行 workflow
   - 可選擇自定義 tag

### 自動構建步驟

1. 檢查工作流程狀態：
   - 前往 GitHub repository → Actions 標籤
   - 查看 "Build and Push to GHCR" workflow

2. 查看構建的鏡像：
   - 前往 repository → Packages（右側）
   - 或直接訪問：`https://github.com/ikigai-kevin-k/telemetry/pkgs/container/telemetry-webhook`

### 標籤策略

工作流程會自動創建以下標籤：

- `latest`: 最新的 main 分支構建
- `main`: main 分支構建
- `<branch-name>`: 特定分支的構建
- `<commit-sha>`: 基於 commit SHA 的標籤
- `pr-<number>`: Pull Request 構建（不推送）

## 手動構建和推送

如果需要手動構建和推送鏡像：

### 1. 登入 GHCR

```bash
# 使用 Personal Access Token (PAT) 登入
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin

# 或使用 GitHub CLI
gh auth token | docker login ghcr.io -u USERNAME --password-stdin
```

**創建 Personal Access Token (PAT)**：
1. GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
2. 生成新 token，選擇 `write:packages` 權限
3. 複製 token 並保存（只顯示一次）

### 2. 構建鏡像

```bash
# 構建鏡像
docker build -f Dockerfile.webhook -t ghcr.io/ikigai-kevin-k/telemetry-webhook:latest .

# 構建特定版本
docker build -f Dockerfile.webhook -t ghcr.io/ikigai-kevin-k/telemetry-webhook:v1.0.0 .
```

### 3. 推送鏡像

```bash
# 推送 latest 標籤
docker push ghcr.io/ikigai-kevin-k/telemetry-webhook:latest

# 推送特定版本
docker push ghcr.io/ikigai-kevin-k/telemetry-webhook:v1.0.0
```

### 4. 驗證推送

```bash
# 查看本地鏡像
docker images | grep telemetry-webhook

# 測試鏡像
docker run -d -p 5000:5000 \
  --name test-webhook \
  ghcr.io/ikigai-kevin-k/telemetry-webhook:latest

# 測試健康檢查
curl http://localhost:5000/health
```

## 使用 GHCR 鏡像

### 更新 docker-compose.yml

在 `docker-compose.yml` 中，將 `webhook-service` 服務的 `build` 改為使用 `image`：

```yaml
webhook-service:
  image: ghcr.io/ikigai-kevin-k/telemetry-webhook:latest
  container_name: kevin-telemetry-webhook
  network_mode: "host"
  volumes:
    - ./grafana_webhook_service.py:/app/grafana_webhook_service.py
  restart: unless-stopped
```

**注意**: 如果使用 volume mount 覆蓋容器內的代碼，鏡像中的代碼會被覆蓋。建議：
- 移除 volume mount（使用鏡像中的代碼）
- 或繼續使用 `build` 方式進行本地開發

### 拉取和使用鏡像

```bash
# 拉取鏡像（需要登入）
docker pull ghcr.io/ikigai-kevin-k/telemetry-webhook:latest

# 使用 docker-compose 啟動
docker compose up -d webhook-service
```

### 使用特定版本

```yaml
webhook-service:
  image: ghcr.io/ikigai-kevin-k/telemetry-webhook:v1.0.0
  # ... 其他配置
```

## 權限設置

### 公開 vs 私有包

默認情況下，GHCR 包是私有的。要設置為公開：

1. 前往 GitHub repository
2. 點擊右側的 "Packages" 區域
3. 選擇 `telemetry-webhook` 包
4. Package settings → Change visibility → Make public

### 協作者權限

要允許其他用戶拉取私有鏡像：

1. 包設置頁面 → Manage access
2. 添加用戶或團隊並授予適當權限

### 在 CI/CD 中使用

GitHub Actions 自動使用 `GITHUB_TOKEN`，無需額外配置。

對於其他 CI/CD 系統（如 Jenkins, GitLab CI），使用 Personal Access Token：

```yaml
# 範例：GitLab CI
variables:
  GHCR_TOKEN: $GITHUB_TOKEN

before_script:
  - echo $GHCR_TOKEN | docker login ghcr.io -u $GITHUB_USERNAME --password-stdin

build:
  script:
    - docker pull ghcr.io/ikigai-kevin-k/telemetry-webhook:latest
```

## 疑難排解

### 1. 認證錯誤

**問題**: `unauthorized: authentication required`

**解決方案**:
```bash
# 確認已登入
docker logout ghcr.io
docker login ghcr.io -u USERNAME

# 確認 token 有正確權限
# GitHub → Settings → Developer settings → Personal access tokens
```

### 2. 推送失敗

**問題**: `denied: permission_denied`

**解決方案**:
- 確認 PAT 有 `write:packages` 權限
- 確認倉庫有正確的訪問權限
- 檢查包的 visibility 設置

### 3. 拉取失敗

**問題**: `pull access denied`

**解決方案**:
```bash
# 登入後再拉取
docker login ghcr.io -u USERNAME

# 確認包是公開的或您有訪問權限
```

### 4. 工作流程不觸發

**檢查**:
- 確認文件變更路徑在 workflow 的 `paths` 中
- 檢查 workflow 文件語法是否正確
- 查看 Actions 頁面的錯誤訊息

### 5. 構建緩存問題

**清理緩存**:
```bash
# 在 GitHub Actions 中，緩存會自動管理
# 本地構建時，可以清理緩存
docker builder prune -a

# 強制重新構建
docker build --no-cache -f Dockerfile.webhook -t ghcr.io/ikigai-kevin-k/telemetry-webhook:latest .
```

## 最佳實踐

### 1. 版本標籤

- 使用語義化版本號（semver）: `v1.0.0`, `v1.0.1`
- 為重要發布打上穩定標籤: `stable`, `production`
- 使用 `latest` 標籤指向最新穩定版本

### 2. 安全性

- Dockerfile 中使用非 root 用戶（已實現）
- 定期更新基礎鏡像
- 掃描鏡像漏洞（GitHub 自動提供）
- 使用最小化基礎鏡像（如 `python:3.10-slim`）

### 3. 構建優化

- 使用多階段構建（如需）
- 利用 Docker layer 緩存
- 使用 `.dockerignore` 排除不必要文件

### 4. 監控

- 定期檢查包的使用情況
- 監控儲存空間使用
- 設置過期策略清理舊鏡像

## 相關資源

- [GitHub Container Registry 文檔](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)
- [Docker 最佳實踐](https://docs.docker.com/develop/dev-best-practices/)
- [GitHub Actions 文檔](https://docs.github.com/en/actions)

## 支援

如有問題，請：
1. 檢查本文檔的疑難排解章節
2. 查看 GitHub Actions 運行日誌
3. 查看 Docker 構建日誌
4. 聯繫專案維護者

