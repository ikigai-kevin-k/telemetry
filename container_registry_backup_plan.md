# Server-Side Monitor Docker 服務備份與上傳方案

## 📋 概述

本文檔詳細說明如何修改 `backup_telemetry_data.sh` 腳本，將 server-side monitor 的所有 Docker 服務設定與資料持久化備份，並上傳到 GitHub Container Registry (ghcr.io)。

## 🎯 需要備份的內容

### 1. Docker Volumes（持久化資料）

以下為所有 server-side 的 Docker volumes：

- `telemetry_alertmanager_data` - Alertmanager 設定與狀態
- `telemetry_grafana_data` - Grafana 儀表板、使用者設定、插件
- `telemetry_loki_data` - Loki 日誌資料
- `telemetry_prometheus_data` - Prometheus 時間序列資料
- `telemetry_zabbix_db_data` - Zabbix MySQL 資料庫（包含所有手動設定）
- `telemetry_zabbix_server_data` - Zabbix Server 配置與緩存
- `telemetry_promtail_aro_001_1_data`（如果屬於 server-side）
- `telemetry_promtail_aro_001_1_positions`（如果屬於 server-side）
- `telemetry_zabbix_agent_aro_001_1_data`（如果屬於 server-side）

### 2. 配置檔案與目錄

- `docker-compose.yml` - Server-side 主要配置
- `prometheus.yml` - Prometheus 配置
- `loki-config.yml` - Loki 配置
- `alertmanager-production.yml` - Alertmanager 配置
- `grafana/` - Grafana 配置目錄（provisioning、grafana.ini）
- `zabbix/` - Zabbix 配置目錄
- `Dockerfile.webhook` - Webhook 服務 Dockerfile
- `grafana_webhook_service.py` - Webhook 服務程式碼
- `byteplus-credentials.env` - 環境變數（需加密處理）
- `telegraf/` - Telegraf 配置（如果存在）

### 3. Docker 映像檔（自定義）

- `telemetry-webhook-service` - 自建的 webhook 服務映像檔

---

## 🔧 修改方案

### 1. 擴充備份腳本功能

需要修改 `backup_telemetry_data.sh` 以新增以下功能：

- ✅ 自動偵測所有 server-side Docker volumes
- ✅ 備份所有相關配置檔案與目錄
- ✅ 匯出自定義 Docker 映像檔（webhook-service）
- ✅ 將備份打包成 tar.gz 壓縮檔
- ✅ 上傳到 GitHub Container Registry (ghcr.io)

### 2. 新增功能模組

#### A. Docker 映像檔備份與推送
- 使用 `docker save` 匯出映像檔
- 使用 `docker tag` 標記為 ghcr.io 格式
- 使用 `docker push` 上傳到 GHCR

#### B. 備份完整性檢查
- 計算備份檔案的 checksum（MD5/SHA256）
- 驗證 tar.gz 檔案完整性
- 生成備份清單（manifest）

#### C. 增量備份支援（可選）
- 僅備份變更的 volumes
- 節省儲存空間與上傳時間

---

## 📝 執行步驟

### 步驟 1：準備 GitHub Container Registry

```bash
# 1.1 建立 GitHub Personal Access Token (PAT)
# 前往：https://github.com/settings/tokens
# 權限需包含：write:packages, read:packages, delete:packages

# 1.2 登入 GitHub Container Registry
echo $GITHUB_PAT | docker login ghcr.io -u <GITHUB_USERNAME> --password-stdin

# 或使用互動式登入
docker login ghcr.io
```

### 步驟 2：修改備份腳本結構

建議新增以下函數：

```bash
# 函數清單
- backup_all_volumes()          # 自動偵測並備份所有 volumes
- backup_all_configs()          # 備份所有配置檔案
- export_docker_images()        # 匯出自定義映像檔
- create_backup_archive()        # 建立 tar.gz 壓縮檔
- upload_to_ghcr()              # 上傳到 GitHub Container Registry
- verify_backup()               # 驗證備份完整性
- generate_manifest()           # 生成備份清單
```

### 步驟 3：備份執行流程

```
1. 建立備份目錄結構
   └── backups/telemetry_backup_YYYYMMDD_HHMMSS/
       ├── volumes/          # Docker volumes 備份
       ├── configs/          # 配置檔案備份
       ├── images/           # Docker 映像檔備份
       ├── backup_info.txt   # 備份元數據
       ├── manifest.json     # 備份清單（含 checksums）
       └── restore.sh        # 恢復腳本

2. 備份 Docker Volumes
   - 逐一備份每個 volume 為 tar.gz
   
3. 備份配置檔案
   - 複製所有配置檔案與目錄
   
4. 匯出 Docker 映像檔
   - docker save telemetry-webhook-service > images/webhook-service.tar
   
5. 建立完整備份壓縮檔
   - tar czf telemetry_backup_YYYYMMDD_HHMMSS.tar.gz *
   
6. 載入並推送映像檔到 GHCR
   - docker load < images/webhook-service.tar
   - docker tag telemetry-webhook-service ghcr.io/<username>/telemetry-webhook-service:latest
   - docker push ghcr.io/<username>/telemetry-webhook-service:latest
   
7. 上傳備份壓縮檔到 GHCR
   - 使用 OCI Artifact 或 GitHub Releases API 上傳 tar.gz
```

### 步驟 4：上傳到 GitHub Container Registry

#### 方法 A：使用 OCI Artifact（推薦）

```bash
# 使用 oras CLI 上傳備份檔案作為 OCI artifact
oras push ghcr.io/<username>/telemetry-backups:YYYYMMDD_HHMMSS \
    telemetry_backup_YYYYMMDD_HHMMSS.tar.gz
```

#### 方法 B：使用 GitHub Releases API

```bash
# 使用 gh CLI 上傳備份檔案作為 release asset
gh release create vYYYYMMDD-HHMMSS \
    telemetry_backup_YYYYMMDD_HHMMSS.tar.gz \
    --title "Telemetry Backup $(date +%Y%m%d_%H%M%S)" \
    --notes "Server-side monitor backup"
```

#### 方法 C：使用 Docker Registry API（直接上傳 tar.gz 作為映像檔層）

```bash
# 將 tar.gz 作為 Docker 映像檔上傳（不推薦，但可行）
docker import telemetry_backup_YYYYMMDD_HHMMSS.tar.gz \
    ghcr.io/<username>/telemetry-backup:YYYYMMDD_HHMMSS
docker push ghcr.io/<username>/telemetry-backup:YYYYMMDD_HHMMSS
```

---

## 🔍 詳細執行指令序列

### 前置作業

```bash
# 1. 安裝必要工具
sudo apt-get update
sudo apt-get install -y jq curl

# 2. 安裝 oras CLI（用於上傳 OCI artifacts）
wget https://github.com/oras-project/oras/releases/download/v1.1.0/oras_1.1.0_linux_amd64.tar.gz
tar -xzf oras_1.1.0_linux_amd64.tar.gz
sudo mv oras /usr/local/bin/

# 3. 設定 GitHub 認證
export GITHUB_USERNAME="your-github-username"
export GITHUB_PAT="your-personal-access-token"
echo $GITHUB_PAT | docker login ghcr.io -u $GITHUB_USERNAME --password-stdin
```

### 備份腳本執行流程（偽碼）

```bash
# 1. 建立備份目錄
BACKUP_DIR="/home/ella/kevin/telemetry/backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="telemetry_backup_${TIMESTAMP}"
mkdir -p "${BACKUP_DIR}/${BACKUP_NAME}/{volumes,configs,images}"

# 2. 備份所有 server-side volumes
for volume in telemetry_alertmanager_data \
              telemetry_grafana_data \
              telemetry_loki_data \
              telemetry_prometheus_data \
              telemetry_zabbix_db_data \
              telemetry_zabbix_server_data; do
    docker run --rm -v "${volume}:/source" \
        -v "${BACKUP_DIR}/${BACKUP_NAME}/volumes:/backup" \
        alpine:latest sh -c "cd /source && tar czf /backup/${volume}.tar.gz ."
done

# 3. 備份配置檔案
cp -r docker-compose.yml \
      prometheus.yml \
      loki-config.yml \
      alertmanager-production.yml \
      grafana/ \
      zabbix/ \
      Dockerfile.webhook \
      grafana_webhook_service.py \
      "${BACKUP_DIR}/${BACKUP_NAME}/configs/"

# 4. 匯出自定義 Docker 映像檔
docker save telemetry-webhook-service:latest \
    -o "${BACKUP_DIR}/${BACKUP_NAME}/images/webhook-service.tar"

# 5. 生成備份清單與 checksums
cd "${BACKUP_DIR}/${BACKUP_NAME}"
find . -type f -exec sha256sum {} \; > manifest.sha256
tar czf "../telemetry_backup_${TIMESTAMP}.tar.gz" .

# 6. 上傳到 GitHub Container Registry
oras push ghcr.io/${GITHUB_USERNAME}/telemetry-backups:${TIMESTAMP} \
    "../telemetry_backup_${TIMESTAMP}.tar.gz" \
    --annotation "org.opencontainers.image.title=Telemetry Server Backup" \
    --annotation "org.opencontainers.image.created=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --annotation "org.opencontainers.image.description=Server-side monitor backup"

# 7. 上傳自定義映像檔（如需要）
docker tag telemetry-webhook-service:latest \
    ghcr.io/${GITHUB_USERNAME}/telemetry-webhook-service:latest
docker push ghcr.io/${GITHUB_USERNAME}/telemetry-webhook-service:latest
```

---

## 🔄 恢復步驟

### 從 GitHub Container Registry 恢復

```bash
# 1. 下載備份檔案
oras pull ghcr.io/<username>/telemetry-backups:YYYYMMDD_HHMMSS \
    -o telemetry_backup.tar.gz

# 2. 解壓縮
tar xzf telemetry_backup.tar.gz

# 3. 恢復 volumes
for volume_tar in volumes/*.tar.gz; do
    volume_name=$(basename $volume_tar .tar.gz)
    docker volume create $volume_name
    docker run --rm -v $volume_name:/target \
        -v $(pwd)/volumes:/backup \
        alpine:latest sh -c "cd /target && tar xzf /backup/$(basename $volume_tar)"
done

# 4. 恢復配置檔案
cp -r configs/* /home/ella/kevin/telemetry/

# 5. 載入 Docker 映像檔
docker load < images/webhook-service.tar

# 6. 啟動服務
cd /home/ella/kevin/telemetry
docker-compose up -d
```

---

## ⚠️ 注意事項

### 1. 安全性

- ⚠️ `byteplus-credentials.env` 包含敏感資訊，上傳前應加密或排除
- ✅ 使用 GitHub Secrets 儲存 PAT
- ✅ 備份檔案建議加密（使用 GPG 或 age）

### 2. 儲存空間

- 📊 GHCR 有儲存限制（免費方案）
- 🔄 考慮定期清理舊備份
- 💾 可使用增量備份減少檔案大小

### 3. 自動化

- ⏰ 可設定 cron job 定期執行備份
- 🌙 建議在低流量時段執行

### 4. 版本標記

- 🏷️ 使用時間戳記作為 tag
- 📌 同時保留 `latest` 指向最新備份

### 5. 驗證機制

- ✅ 備份後驗證完整性
- 🧪 定期測試恢復流程

---

## 🛠️ 建議的腳本修改重點

### 1. 新增變數區塊

```bash
# GitHub Container Registry 設定
GITHUB_USERNAME="${GITHUB_USERNAME:-}"
GITHUB_PAT="${GITHUB_PAT:-}"  # 從環境變數讀取
GHCR_REPOSITORY="${GHCR_REPOSITORY:-telemetry-backups}"
GHCR_IMAGE_REPOSITORY="${GHCR_IMAGE_REPOSITORY:-telemetry-webhook-service}"
```

### 2. 新增函數

- `detect_server_volumes()` - 自動偵測所有 server-side volumes
- `export_custom_images()` - 匯出自定義映像檔
- `upload_to_ghcr()` - 上傳到 GHCR
- `verify_backup_integrity()` - 驗證備份完整性

### 3. 修改 `backup_config_files()` 函數

- 擴充配置檔案清單
- 排除敏感檔案或加密處理

### 4. 修改 `main()` 函數

- 加入上傳到 GHCR 的流程
- 加入錯誤處理與重試機制

---

## 📚 相關資源

- [GitHub Container Registry 文件](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)
- [ORAS CLI 文件](https://oras.land/docs/cli)
- [Docker Registry API](https://docs.docker.com/registry/spec/api/)
- [OCI Artifacts 規格](https://github.com/opencontainers/artifacts)

---

**⚠️ 重要提醒**：
1. 執行備份前務必確認 GitHub Container Registry 認證已設定
2. 建議先在小範圍測試備份與恢復流程
3. 定期驗證備份檔案的完整性
4. 妥善保管 GitHub Personal Access Token

*最後更新: $(date +%Y年%m月%d日)*  
*文檔版本: 1.0*

