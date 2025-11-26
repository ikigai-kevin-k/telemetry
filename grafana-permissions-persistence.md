# Grafana 權限設定持久化指南

## 概述

本文件說明如何確保 Grafana 的權限設定（Dashboard、Folder、Datasource 權限）在容器重啟後能夠持久化保存。

## ✅ 持久化狀態確認

### 目前配置狀態

您的 Grafana 已經正確配置了持久化儲存：

1. **Docker Volume 配置**：
   - Volume 名稱: `telemetry_grafana_data`
   - 掛載點: `/var/lib/docker/volumes/telemetry_grafana_data/_data`
   - 容器內路徑: `/var/lib/grafana`

2. **Docker Compose 配置**：
```yaml
grafana:
  volumes:
    - grafana_data:/var/lib/grafana  # ✅ 持久化儲存
```

3. **權限資料儲存位置**：
   - Grafana 資料庫: `/var/lib/grafana/grafana.db`
   - 權限資料表:
     - `dashboard_acl` - Dashboard 權限
     - `folder_acl` - Folder 權限
     - `datasource_acl` - Datasource 權限

## 🔍 驗證持久化設定

### 方法一：使用驗證腳本（推薦）

執行驗證腳本檢查持久化狀態：

```bash
./scripts/verify-grafana-permissions-persistence.sh
```

這個腳本會檢查：
- ✅ Docker volume 是否存在
- ✅ Volume 是否正確掛載
- ✅ Grafana 資料庫是否存在
- ✅ 權限資料是否已儲存
- ✅ 備份狀態

### 方法二：手動驗證

```bash
# 1. 檢查 volume 是否存在
docker volume inspect telemetry_grafana_data

# 2. 檢查 volume 掛載
docker inspect kevin-telemetry-grafana | jq '.[0].Mounts[] | select(.Destination == "/var/lib/grafana")'

# 3. 檢查資料庫檔案
docker exec kevin-telemetry-grafana ls -lh /var/lib/grafana/grafana.db

# 4. 檢查權限資料（如果 SQLite3 可用）
docker exec kevin-telemetry-grafana sqlite3 /var/lib/grafana/grafana.db \
  "SELECT COUNT(*) FROM dashboard_acl;"
```

## 💾 備份權限設定

### 立即備份（建議在設定權限後執行）

```bash
./scripts/backup-grafana-permissions.sh
```

這個腳本會：
- ✅ 備份 Grafana 完整資料庫
- ✅ 匯出權限資料為 CSV 格式
- ✅ 可選：備份完整 volume
- ✅ 建立備份資訊檔案

### 備份內容

備份會包含：
- `grafana.db` - 完整資料庫（包含所有權限）
- `dashboard_acl.csv` - Dashboard 權限資料
- `folder_acl.csv` - Folder 權限資料
- `datasource_acl.csv` - Datasource 權限資料
- `backup_info.txt` - 備份資訊和恢復說明

### 備份位置

備份檔案會儲存在：
```
./backups/grafana_permissions_YYYYMMDD_HHMMSS/
```

## 🔄 測試持久化

### 測試步驟

1. **記錄目前的權限設定**：
   ```bash
   # 使用 Viewer 帳號登入，確認可以看到 "Round Stat" dashboard
   # 記錄哪些 dashboard 可見/不可見
   ```

2. **重啟 Grafana**：
   ```bash
   docker-compose restart grafana
   ```

3. **等待服務啟動**（約 10-30 秒）：
   ```bash
   docker-compose ps grafana
   # 確認狀態為 "Up"
   ```

4. **驗證權限是否保留**：
   - 使用 Viewer 帳號登入
   - 檢查是否仍只能看到 "Round Stat" dashboard
   - 確認其他 dashboard 仍然不可見

5. **驗證 Admin 權限**：
   - 使用 Admin 帳號登入
   - 確認所有 dashboard 都可正常存取

### 預期結果

✅ **成功**：
- Viewer 帳號重啟後仍只能看到 "Round Stat"
- Admin 帳號重啟後仍可看到所有 dashboard
- 所有權限設定保持不變

❌ **失敗**（如果發生）：
- Viewer 可以看到所有 dashboard（權限未保留）
- 需要從備份恢復或重新設定權限

## 🛡️ 確保持久化的最佳實踐

### 1. 定期備份

建議在以下時機備份：
- ✅ 設定權限後立即備份
- ✅ 每週定期備份
- ✅ 重大變更前備份

```bash
# 設定權限後立即備份
./scripts/backup-grafana-permissions.sh

# 或加入定期備份（cron）
0 2 * * 0 cd /home/ella/kevin/telemetry && ./scripts/backup-grafana-permissions.sh
```

### 2. 驗證 Volume 配置

確保 `docker-compose.yml` 中 Grafana 服務有正確的 volume 配置：

```yaml
grafana:
  volumes:
    - grafana_data:/var/lib/grafana  # ✅ 必須存在
```

### 3. 避免直接刪除 Volume

⚠️ **重要**：不要執行以下命令（會刪除所有資料）：
```bash
# ❌ 不要執行
docker volume rm telemetry_grafana_data
```

### 4. 使用正確的重啟方式

✅ **正確的重啟方式**：
```bash
# 重啟服務（保留資料）
docker-compose restart grafana

# 或停止後啟動
docker-compose stop grafana
docker-compose start grafana
```

❌ **錯誤的重啟方式**（會刪除資料）：
```bash
# ❌ 不要執行（會刪除未持久化的資料）
docker-compose down
docker-compose up -d
# 注意：如果 volume 配置正確，這個命令不會刪除資料，但為安全起見建議使用 restart
```

## 🔧 故障排除

### 問題 1: 重啟後權限遺失

**可能原因**：
- Volume 未正確掛載
- 資料庫檔案損壞
- Volume 被意外刪除

**解決方案**：
1. 檢查 volume 掛載：
   ```bash
   docker inspect kevin-telemetry-grafana | jq '.[0].Mounts[]'
   ```

2. 從備份恢復：
   ```bash
   # 停止 Grafana
   docker-compose stop grafana
   
   # 恢復資料庫
   docker cp backups/grafana_permissions_YYYYMMDD_HHMMSS/grafana.db \
     kevin-telemetry-grafana:/var/lib/grafana/grafana.db
   
   # 設定正確權限
   docker exec kevin-telemetry-grafana chown grafana:grafana \
     /var/lib/grafana/grafana.db
   
   # 啟動 Grafana
   docker-compose start grafana
   ```

3. 如果沒有備份，需要重新設定權限

### 問題 2: Volume 不存在

**解決方案**：
```bash
# 檢查 volume
docker volume ls | grep grafana_data

# 如果不存在，重新建立（注意：會遺失現有資料）
docker volume create telemetry_grafana_data

# 重新啟動服務
docker-compose up -d grafana
```

### 問題 3: 權限設定無法儲存

**可能原因**：
- 資料庫檔案權限問題
- 磁碟空間不足

**解決方案**：
```bash
# 檢查資料庫檔案權限
docker exec kevin-telemetry-grafana ls -l /var/lib/grafana/grafana.db

# 檢查磁碟空間
df -h

# 檢查容器日誌
docker-compose logs grafana | tail -50
```

## 📋 檢查清單

在設定權限後，請確認：

- [ ] 已執行驗證腳本確認持久化配置
- [ ] 已建立權限備份
- [ ] 已測試重啟後權限是否保留
- [ ] 已記錄備份位置
- [ ] 已確認 volume 配置正確

## 📚 相關檔案

- `docker-compose.yml` - Docker Compose 配置
- `scripts/verify-grafana-permissions-persistence.sh` - 驗證腳本
- `scripts/backup-grafana-permissions.sh` - 備份腳本
- `grafana-restrict-dashboard-access.md` - 權限設定指南

## 🔗 參考資料

- [Grafana 資料持久化文件](https://grafana.com/docs/grafana/latest/setup-grafana/configure-docker/#persist-grafana-data)
- [Docker Volume 文件](https://docs.docker.com/storage/volumes/)









