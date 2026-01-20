# 監控系統備份恢復使用指南

## 📋 概述

本文檔詳細說明 Telemetry 監控系統的備份歷史位置、使用方法以及完整的恢復程序。系統包含 Zabbix、Grafana、Loki 和 Prometheus 等組件，所有數據和配置都通過 Docker Volume 實現持久化存儲。

## 📂 備份歷史位置

### 備份根目錄
```
/home/ella/kevin/telemetry/backups/
```

### 當前備份列表
| 備份名稱 | 創建時間 | 狀態 | 大小 |
|----------|----------|------|------|
| `telemetry_backup_20250917_133003` | 2025-09-17 13:30:03 | ✅ 最新 | 187MB |
| `telemetry_backup_20250917_092112` | 2025-09-17 09:21:12 | ✅ 可用 | - |
| `telemetry_backup_20250917_092034` | 2025-09-17 09:20:34 | ✅ 可用 | - |
| `telemetry_backup_20250917_091931` | 2025-09-17 09:19:31 | ✅ 可用 | - |

### 備份目錄結構
```
telemetry_backup_YYYYMMDD_HHMMSS/
├── backup_info.txt          # 備份元數據信息
├── restore.sh              # 自動恢復腳本
├── volumes/                # Docker Volume 備份
│   ├── prometheus_data.tar.gz      # Prometheus 時間序列數據
│   ├── grafana_data.tar.gz         # Grafana 儀表板和配置
│   ├── loki_data.tar.gz           # Loki 日誌數據
│   ├── zabbix_server_data.tar.gz  # Zabbix 伺服器配置
│   └── zabbix_db_data.tar.gz      # Zabbix 數據庫 (包含所有手動設定)
└── configs/                # 配置檔案備份
    ├── docker-compose*.yml         # Docker Compose 配置
    ├── prometheus.yml             # Prometheus 配置
    ├── loki-config.yml            # Loki 配置
    ├── grafana/                   # Grafana 配置目錄
    ├── zabbix/                    # Zabbix 配置目錄
    └── promtail-*.yml             # Promtail 配置檔案
```

## 🔧 備份使用方法

### 1. 手動執行備份

```bash
# 進入專案目錄
cd /home/ella/kevin/telemetry

# 執行備份腳本
./backup_telemetry_data.sh
```

### 2. 檢查備份狀態

```bash
# 查看最新備份
ls -lt /home/ella/kevin/telemetry/backups/ | head -5

# 檢查備份內容
ls -la /home/ella/kevin/telemetry/backups/telemetry_backup_20250917_133003/

# 查看備份大小
du -sh /home/ella/kevin/telemetry/backups/telemetry_backup_20250917_133003/
```

### 3. 備份內容驗證

```bash
# 檢查 Zabbix 數據庫備份完整性
tar -tzf /home/ella/kevin/telemetry/backups/telemetry_backup_20250917_133003/volumes/zabbix_db_data.tar.gz | head -10

# 檢查備份元數據
cat /home/ella/kevin/telemetry/backups/telemetry_backup_20250917_133003/backup_info.txt
```

## 🔄 恢復使用方法

### 方法一：使用自動恢復腳本（推薦）

```bash
# 1. 停止所有容器
cd /home/ella/kevin/telemetry
docker-compose down

# 2. 執行恢復腳本
./backups/telemetry_backup_20250917_133003/restore.sh

# 3. 重新啟動服務
docker-compose up -d

# 4. 驗證恢復狀態
docker-compose ps
```

### 方法二：手動恢復特定 Volume

```bash
# 恢復 Prometheus 數據
docker volume create telemetry_prometheus_data
docker run --rm -v telemetry_prometheus_data:/target -v /home/ella/kevin/telemetry/backups/telemetry_backup_20250917_133003:/backup \
    alpine:latest sh -c "cd /target && tar xzf /backup/volumes/prometheus_data.tar.gz"

# 恢復 Grafana 數據
docker volume create telemetry_grafana_data
docker run --rm -v telemetry_grafana_data:/target -v /home/ella/kevin/telemetry/backups/telemetry_backup_20250917_133003:/backup \
    alpine:latest sh -c "cd /target && tar xzf /backup/volumes/grafana_data.tar.gz"

# 恢復 Zabbix 數據庫
docker volume create telemetry_zabbix_db_data
docker run --rm -v telemetry_zabbix_db_data:/target -v /home/ella/kevin/telemetry/backups/telemetry_backup_20250917_133003:/backup \
    alpine:latest sh -c "cd /target && tar xzf /backup/volumes/zabbix_db_data.tar.gz"
```

### 方法三：恢復到特定時間點

```bash
# 選擇要恢復的備份時間點
BACKUP_DIR="/home/ella/kevin/telemetry/backups/telemetry_backup_20250917_092112"

# 停止服務
docker-compose down

# 執行恢復
$BACKUP_DIR/restore.sh

# 重新啟動
docker-compose up -d
```

## ✅ 恢復後驗證

### 1. 檢查容器狀態
```bash
# 檢查所有容器是否正常運行
docker-compose ps

# 預期輸出：所有容器狀態應為 "Up"
```

### 2. 驗證 Zabbix 手動設定
```bash
# 檢查手動設定的 triggers 是否恢復
docker exec -it kevin-telemetry-zabbix-db mysql -u zabbix -pzabbix_pwd \
  -e "SELECT triggerid, description, expression FROM triggers WHERE description LIKE '%usage too high%';" zabbix

# 預期輸出：
# +-----------+-----------------------+-------------+
# | triggerid | description           | expression  |
# +-----------+-----------------------+-------------+
# |     24524 | CPU usage too high    | {34949}>=10 |
# |     24525 | Memory usage too high | {34950}>=10 |
# |     24526 | Disk usage too high   | {34951}>=10 |
# +-----------+-----------------------+-------------+
```

### 3. 檢查服務可訪問性
```bash
# 檢查各服務端口
curl -s http://localhost:3000 | grep -i grafana    # Grafana (3000)
curl -s http://localhost:9090 | grep -i prometheus # Prometheus (9090)
curl -s http://localhost:3100/ready                # Loki (3100)
curl -s http://localhost:8080 | grep -i zabbix     # Zabbix Web (8080)
```

### 4. 驗證數據完整性
```bash
# 檢查總 trigger 數量
docker exec -it kevin-telemetry-zabbix-db mysql -u zabbix -pzabbix_pwd \
  -e "SELECT COUNT(*) as total_triggers FROM triggers;" zabbix

# 預期輸出：total_triggers 應接近 6733
```

## 🛡️ 備份管理最佳實踐

### 1. 定期備份
```bash
# 建議每日執行備份
# 可設置 cron job：
# 0 2 * * * cd /home/ella/kevin/telemetry && ./backup_telemetry_data.sh
```

### 2. 備份清理
```bash
# 保留最近 7 天的備份，刪除舊備份
find /home/ella/kevin/telemetry/backups/ -type d -name "telemetry_backup_*" -mtime +7 -exec rm -rf {} \;
```

### 3. 備份驗證
```bash
# 定期驗證備份完整性
for backup in /home/ella/kevin/telemetry/backups/telemetry_backup_*/volumes/zabbix_db_data.tar.gz; do
    echo "驗證備份: $backup"
    tar -tzf "$backup" > /dev/null && echo "✅ 完整" || echo "❌ 損壞"
done
```

## 🚨 故障排除

### 常見問題及解決方案

#### 1. 恢復後容器無法啟動
```bash
# 檢查 Docker Volume 權限
sudo ls -la /var/lib/docker/volumes/telemetry_*/

# 修正權限（如需要）
sudo chown -R 999:999 /var/lib/docker/volumes/telemetry_zabbix_db_data/_data
```

#### 2. 數據庫連接失敗
```bash
# 檢查 MySQL 容器日誌
docker logs kevin-telemetry-zabbix-db

# 重新初始化數據庫（謹慎使用）
docker-compose down
docker volume rm telemetry_zabbix_db_data
docker-compose up -d
```

#### 3. 配置檔案不匹配
```bash
# 恢復配置檔案
cp /home/ella/kevin/telemetry/backups/telemetry_backup_20250917_133003/configs/docker-compose.yml .
cp /home/ella/kevin/telemetry/backups/telemetry_backup_20250917_133003/configs/prometheus.yml .
```

## 📊 備份統計信息

### 最新備份詳情 (telemetry_backup_20250917_133003)
- **備份時間**: 2025年9月17日 13:30:03
- **總大小**: 187MB
- **包含組件**: 
  - Prometheus (14MB)
  - Grafana (30MB) 
  - Loki (4KB)
  - Zabbix 伺服器 (4KB)
  - Zabbix 數據庫 (144MB)
- **配置檔案**: 17 個配置檔案
- **恢復腳本**: ✅ 已生成

### 數據完整性確認
- ✅ 所有 Docker Volumes 已備份
- ✅ 所有配置檔案已備份
- ✅ Zabbix 手動設定已保存 (6,733 triggers)
- ✅ 恢復腳本已生成並可執行
- ✅ 備份元數據完整

## 🔗 相關文檔

- [Zabbix 手動設定數據持久化說明](zabbix_manual_setting_data_persistence.md)
- [Docker Compose 配置](docker-compose.yml)
- [備份腳本源碼](backup_telemetry_data.sh)

---

**⚠️ 重要提醒**：
1. 執行恢復前務必停止所有相關容器
2. 建議在恢復前創建當前狀態的備份
3. 恢復後務必執行驗證步驟確認數據完整性
4. 定期測試恢復程序以確保備份可用性

*最後更新: 2025年9月17日*  
*文檔版本: 1.0*
