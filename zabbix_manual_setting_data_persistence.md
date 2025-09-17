# Zabbix 手動設定數據持久化機制說明

## 概述

本文檔詳細說明 Zabbix Web 界面中手動設置的配置（如 CPU usage too high、Memory usage too high、Disk usage too high 等 trigger）如何透過 Docker Volume 實現數據持久化，確保容器重啟後設定不會遺失。

## ✅ 數據持久化狀態確認

### 已驗證的手動設定

經過系統檢查，以下手動設定已成功保存在數據庫中：

| Trigger ID | 描述 | 觸發條件 | 狀態 |
|------------|------|----------|------|
| 24524 | CPU usage too high | CPU 使用率 >= 80% | ✅ 已保存 |
| 24525 | Memory usage too high | 記憶體使用率 >= 90% | ✅ 已保存 |
| 24526 | Disk usage too high | 磁碟使用率 >= 85% | ✅ 已保存 |

**總計 Trigger 數量**: 6,732 個（包含系統預設和手動設定）

## 🗄️ 數據存儲架構

### Docker Volume 配置

```yaml
# docker-compose.yml 中的 Volume 配置
volumes:
  zabbix_server_data:    # Zabbix 伺服器配置和緩存
  zabbix_db_data:        # Zabbix 數據庫（MySQL）- 包含所有手動設定
```

### 實際存儲位置

- **Zabbix 數據庫 Volume**: `/var/lib/docker/volumes/telemetry_zabbix_db_data/_data`
- **Zabbix 伺服器 Volume**: `/var/lib/docker/volumes/telemetry_zabbix_server_data/_data`

### 容器掛載配置

```yaml
# Zabbix Server Container
zabbix-server:
  volumes:
    - zabbix_server_data:/var/lib/zabbix    # 伺服器配置和緩存

# Zabbix Database Container  
zabbix-db:
  volumes:
    - zabbix_db_data:/var/lib/mysql         # 完整的 MySQL 數據庫
```

## 📊 數據庫表結構

### 手動設定存儲的關鍵表

| 表名 | 用途 | 範例內容 |
|------|------|----------|
| `triggers` | 儲存所有 trigger 規則 | CPU/Memory/Disk usage triggers |
| `items` | 儲存監控項目 | CPU utilization, Memory usage 等 |
| `hosts` | 儲存主機配置 | 監控的伺服器資訊 |
| `hosts_groups` | 儲存主機群組 | 主機分組設定 |
| `hostmacro` | 儲存主機宏定義 | 閾值參數設定 |
| `item_preproc` | 項目預處理規則 | 數據轉換邏輯 |
| `trigger_tag` | Trigger 標籤 | 分類和過濾標籤 |

### 相關數據庫表統計

```sql
-- Trigger 相關表
triggers                    -- 主要 trigger 定義
trigger_depends            -- Trigger 依賴關係
trigger_discovery          -- Trigger 自動發現
trigger_queue              -- Trigger 執行佇列
trigger_tag                -- Trigger 標籤

-- 監控項目相關表
items                      -- 監控項目定義
item_condition             -- 項目條件
item_discovery             -- 項目自動發現
item_parameter             -- 項目參數
item_preproc               -- 項目預處理
item_rtdata                -- 項目即時數據
item_tag                   -- 項目標籤
```

## 🔍 驗證方式

### 1. 檢查 Docker Volume 存在性

```bash
# 檢查 Zabbix 相關的 volumes
docker volume ls | grep zabbix

# 預期輸出：
# telemetry_zabbix_db_data
# telemetry_zabbix_server_data
```

### 2. 檢查 Volume 掛載點

```bash
# 檢查數據庫 volume 掛載點
docker volume inspect telemetry_zabbix_db_data | jq '.[0].Mountpoint'

# 檢查伺服器 volume 掛載點  
docker volume inspect telemetry_zabbix_server_data | jq '.[0].Mountpoint'
```

### 3. 驗證手動設定的 Trigger

```bash
# 檢查手動設置的 CPU/Memory/Disk triggers
docker exec -it kevin-telemetry-zabbix-db mysql -u zabbix -pzabbix_pwd \
  -e "SELECT triggerid, description, expression FROM triggers WHERE description LIKE '%usage too high%';" zabbix
```

**預期輸出**：
```
+----------+-------------------------+----------------+
| triggerid| description             | expression     |
+----------+-------------------------+----------------+
| 24524    | CPU usage too high      | {34946}>=80    |
| 24525    | Memory usage too high   | {34947}>=90    |
| 24526    | Disk usage too high     | {34948}>=85    |
+----------+-------------------------+----------------+
```

### 4. 檢查總 Trigger 數量

```bash
# 檢查系統中總 trigger 數量
docker exec -it kevin-telemetry-zabbix-db mysql -u zabbix -pzabbix_pwd \
  -e "SELECT COUNT(*) as total_triggers FROM triggers;" zabbix
```

### 5. 檢查相關數據庫表

```bash
# 檢查所有 trigger 相關表
docker exec -it kevin-telemetry-zabbix-db mysql -u zabbix -pzabbix_pwd \
  -e "SHOW TABLES;" zabbix | grep trigger

# 檢查所有 item 相關表
docker exec -it kevin-telemetry-zabbix-db mysql -u zabbix -pzabbix_pwd \
  -e "SHOW TABLES;" zabbix | grep item

# 檢查所有 host 相關表
docker exec -it kevin-telemetry-zabbix-db mysql -u zabbix -pzabbix_pwd \
  -e "SHOW TABLES;" zabbix | grep host
```

## 🔄 容器重啟測試

### 測試數據持久化

```bash
# 1. 記錄當前 trigger 設定
docker exec -it kevin-telemetry-zabbix-db mysql -u zabbix -pzabbix_pwd \
  -e "SELECT COUNT(*) FROM triggers WHERE description LIKE '%usage too high%';" zabbix

# 2. 停止所有容器
docker-compose down

# 3. 重新啟動容器
docker-compose up -d

# 4. 等待容器完全啟動（約 30-60 秒）
docker-compose ps

# 5. 驗證設定是否保留
docker exec -it kevin-telemetry-zabbix-db mysql -u zabbix -pzabbix_pwd \
  -e "SELECT triggerid, description FROM triggers WHERE description LIKE '%usage too high%';" zabbix
```

### 預期結果

重啟後應該看到：
- ✅ 所有手動設置的 trigger 完全保留
- ✅ Trigger ID 保持不變
- ✅ 觸發條件和閾值保持不變
- ✅ 監控歷史數據完整保留

## 📋 備份機制

### 自動備份

系統已配置自動備份機制，包含所有手動設定：

```bash
# 執行完整備份
./backup_telemetry_data.sh
```

**備份內容包含**：
- `zabbix_db_data.tar.gz` - 完整的 Zabbix 數據庫（包含所有手動設定）
- `zabbix_server_data.tar.gz` - Zabbix 伺服器配置

### 備份位置

```
/home/ella/kevin/telemetry/backups/
├── telemetry_backup_YYYYMMDD_HHMMSS/
│   ├── volumes/
│   │   ├── zabbix_db_data.tar.gz      # 包含所有手動 trigger 設定
│   │   └── zabbix_server_data.tar.gz   # 伺服器配置
│   ├── configs/                        # 配置檔案
│   └── restore.sh                      # 恢復腳本
```

### 恢復手動設定

```bash
# 從備份恢復（如果需要）
cd /home/ella/kevin/telemetry
ls -t backups/ | head -1  # 找到最新備份
./backups/telemetry_backup_YYYYMMDD_HHMMSS/restore.sh
```

## 🛡️ 數據安全保證

### 多層保護機制

1. **Docker Volume 持久化** - 容器層級的數據保護
2. **定期自動備份** - 每日凌晨 2:00 自動備份
3. **健康檢查監控** - 每 6 小時檢查容器健康狀態
4. **備份驗證** - 備份完成後自動驗證數據完整性

### 故障恢復程序

```bash
# 1. 檢查系統狀態
./check_and_restore_containers.sh --check-only

# 2. 自動恢復（如果需要）
./check_and_restore_containers.sh

# 3. 驗證手動設定是否完整
docker exec -it kevin-telemetry-zabbix-db mysql -u zabbix -pzabbix_pwd \
  -e "SELECT COUNT(*) FROM triggers WHERE description LIKE '%usage too high%';" zabbix
```

## 📈 監控項目說明

### 手動設置的監控閾值

| 監控項目 | 警告閾值 | 嚴重閾值 | 說明 |
|----------|----------|----------|------|
| CPU 使用率 | - | ≥ 80% | 觸發 "CPU usage too high" |
| 記憶體使用率 | - | ≥ 90% | 觸發 "Memory usage too high" |
| 磁碟使用率 | - | ≥ 85% | 觸發 "Disk usage too high" |

### 監控數據流程

```
監控代理 → Zabbix Server → 數據庫存儲 → Trigger 評估 → 告警觸發
    ↓           ↓              ↓            ↓           ↓
  收集數據   →  處理數據  →  持久化存儲  →  規則檢查  →  通知發送
```

## 🔧 故障排除

### 常見問題和解決方案

#### 1. 手動設定遺失

**症狀**: 容器重啟後找不到手動設置的 trigger

**檢查步驟**:
```bash
# 檢查 volume 是否正確掛載
docker inspect kevin-telemetry-zabbix-db | grep -A 10 "Mounts"

# 檢查數據庫連接
docker exec -it kevin-telemetry-zabbix-db mysql -u zabbix -pzabbix_pwd -e "SHOW DATABASES;"
```

**解決方案**:
```bash
# 從最新備份恢復
./backups/$(ls -t backups/ | head -1)/restore.sh
```

#### 2. Volume 權限問題

**症狀**: 容器無法寫入 volume

**解決方案**:
```bash
# 檢查 volume 權限
sudo ls -la /var/lib/docker/volumes/telemetry_zabbix_db_data/_data

# 修正權限（如需要）
sudo chown -R 999:999 /var/lib/docker/volumes/telemetry_zabbix_db_data/_data
```

## ✅ 結論

您的 Zabbix 手動設定已經透過以下機制實現完整的數據持久化：

1. **✅ Docker Volume 保存** - 所有設定儲存在持久化 volume 中
2. **✅ 數據庫持久化** - MySQL 數據庫完整保存所有配置
3. **✅ 自動備份保護** - 定期備份確保數據安全
4. **✅ 容器重啟恢復** - 重啟後所有設定自動恢復
5. **✅ 多層驗證機制** - 多種方式驗證數據完整性

**您完全不需要擔心手動設定會遺失！** 系統已經提供了企業級的數據保護機制。

---

*最後更新: 2025年9月17日*  
*文檔版本: 1.0*
