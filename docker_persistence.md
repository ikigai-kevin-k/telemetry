# Docker 數據持久化配置與備份系統

## 概述

本文檔記錄了 Telemetry 系統的 Docker 數據持久化配置、備份系統建立以及相關測試驗證的完整過程。

## 系統配置狀態

### Docker Volumes 配置

系統已配置以下 Docker volumes 用於數據持久化：

| 服務 | Volume 名稱 | 掛載路徑 | 用途 |
|------|-------------|----------|------|
| Prometheus | `telemetry_prometheus_data` | `/prometheus` | 存儲指標數據 |
| Grafana | `telemetry_grafana_data` | `/var/lib/grafana` | 存儲儀表板和配置 |
| Loki | `telemetry_loki_data` | `/loki` | 存儲日誌數據 |
| Zabbix Server | `telemetry_zabbix_server_data` | `/var/lib/zabbix` | 存儲 Zabbix 服務器數據 |
| Zabbix Database | `telemetry_zabbix_db_data` | `/var/lib/mysql` | 存儲 Zabbix 數據庫 |

### Docker Compose 配置

主要服務在 `docker-compose.yml` 中的持久化配置：

```yaml
volumes:
  prometheus_data:
  grafana_data:
  loki_data:
  zabbix_server_data:
  zabbix_db_data:
```

## 建立的備份和恢復系統

### 1. 完整備份腳本 (`backup_telemetry_data.sh`)

**功能**：
- 備份所有 Docker volumes
- 備份配置檔案
- 生成恢復腳本
- 創建備份元數據

**使用方法**：
```bash
./backup_telemetry_data.sh
```

**備份內容**：
- Docker volumes: prometheus_data, grafana_data, loki_data, zabbix_server_data, zabbix_db_data
- 配置檔案: docker-compose.yml, prometheus.yml, loki-config.yml, grafana 配置, zabbix 配置
- 備份元數據和恢復腳本

### 2. 健康檢查和恢復腳本 (`check_and_restore_containers.sh`)

**功能**：
- 檢查容器健康狀態
- 驗證數據持久化
- 自動恢復失敗的容器
- 緊急備份功能

**使用方法**：
```bash
# 僅檢查健康狀態
./check_and_restore_containers.sh --check-only

# 完整健康檢查和自動恢復
./check_and_restore_containers.sh

# 創建緊急備份
./check_and_restore_containers.sh --backup

# 從備份恢復
./check_and_restore_containers.sh --restore
```

### 3. 數據持久化測試腳本 (`test_data_persistence.sh`)

**功能**：
- 測試 Grafana 數據持久化
- 測試 Prometheus 數據持久化
- 測試 Zabbix 數據持久化
- 測試容器重啟後數據恢復

**使用方法**：
```bash
./test_data_persistence.sh
```

### 4. 自動化備份設置腳本 (`setup_automated_backup.sh`)

**功能**：
- 設置 cron 定時任務
- 配置日誌輪轉
- 創建清理腳本
- 生成系統服務配置

**使用方法**：
```bash
./setup_automated_backup.sh
```

## 測試驗證結果

### 數據持久化測試

所有測試均已通過：

- ✅ **Grafana 數據持久化** - 配置和儀表板數據已保存
- ✅ **Prometheus 數據持久化** - 指標數據已保存
- ✅ **Zabbix 數據持久化** - 監控配置和歷史數據已保存
- ✅ **容器重啟測試** - 數據在容器重啟後仍然存在

### 備份系統測試

- ✅ 成功創建完整備份 (大小約 182MB)
- ✅ 備份包含所有 volumes 和配置檔案
- ✅ 恢復腳本正常工作
- ✅ 緊急備份功能正常

## 自動化配置

### Cron 定時任務

建議的 cron 配置：

```bash
# 每日備份 (凌晨 2:00)
0 2 * * * cd /home/ella/kevin/telemetry && ./backup_telemetry_data.sh >> /var/log/telemetry_backup.log 2>&1

# 健康檢查 (每 6 小時)
0 */6 * * * cd /home/ella/kevin/telemetry && ./check_and_restore_containers.sh --check-only >> /var/log/telemetry_health.log 2>&1

# 週清理 (週日凌晨 3:00)
0 3 * * 0 cd /home/ella/kevin/telemetry && ./cleanup_old_backups.sh >> /var/log/telemetry_cleanup.log 2>&1
```

### 系統服務配置

可選的 systemd 服務配置：

- `telemetry-backup.service` - 備份服務
- `telemetry-backup.timer` - 備份定時器
- `telemetry-health.service` - 健康檢查服務
- `telemetry-health.timer` - 健康檢查定時器

## 意外恢復程序

### 自動恢復（推薦）

1. 運行健康檢查：
   ```bash
   ./check_and_restore_containers.sh --check-only
   ```

2. 執行自動恢復：
   ```bash
   ./check_and_restore_containers.sh
   ```

### 手動恢復

1. 停止所有容器：
   ```bash
   docker-compose down
   ```

2. 從備份恢復：
   ```bash
   # 找到最新備份
   ls -t backups/ | head -1
   
   # 執行恢復
   ./backups/telemetry_backup_YYYYMMDD_HHMMSS/restore.sh
   ```

3. 重新啟動服務：
   ```bash
   docker-compose up -d
   ```

## 備份管理

### 備份位置

- 主備份目錄：`/home/ella/kevin/telemetry/backups/`
- 備份命名格式：`telemetry_backup_YYYYMMDD_HHMMSS`
- 每個備份包含：
  - `volumes/` - Docker volumes 備份
  - `configs/` - 配置檔案備份
  - `backup_info.txt` - 備份元數據
  - `restore.sh` - 恢復腳本

### 備份清理

- 保留最近 30 天的每日備份
- 保留最近 52 週的每週備份
- 自動清理腳本：`cleanup_old_backups.sh`

## 監控和維護

### 日常監控命令

```bash
# 檢查容器狀態
docker ps

# 檢查 volumes
docker volume ls

# 檢查備份
ls -la backups/

# 運行健康檢查
./check_and_restore_containers.sh --check-only

# 創建手動備份
./backup_telemetry_data.sh
```

### 日誌文件

- 備份日誌：`/var/log/telemetry_backup.log`
- 健康檢查日誌：`/var/log/telemetry_health.log`
- 清理日誌：`/var/log/telemetry_cleanup.log`
- 容器健康日誌：`/home/ella/kevin/telemetry/container_health.log`

## 重要檔案清單

### 新增的腳本檔案

- `backup_telemetry_data.sh` - 完整備份腳本
- `check_and_restore_containers.sh` - 健康檢查和恢復腳本
- `test_data_persistence.sh` - 數據持久化測試腳本
- `setup_automated_backup.sh` - 自動化備份設置腳本
- `cleanup_old_backups.sh` - 備份清理腳本

### 系統服務檔案

- `telemetry-backup.service` - 備份服務配置
- `telemetry-backup.timer` - 備份定時器配置
- `telemetry-health.service` - 健康檢查服務配置
- `telemetry-health.timer` - 健康檢查定時器配置

### 文檔檔案

- `DATA_PERSISTENCE_SUMMARY.md` - 數據持久化總結
- `docker_persistence.md` - 本文檔
- `MONITORING_INFO.md` - 監控信息文檔

## 配置修改記錄

### Docker Compose 修改

- 確認所有服務的 volumes 配置正確
- 驗證 restart 策略設置為 `unless-stopped`

### 腳本權限設置

所有腳本已設置執行權限：
```bash
chmod +x backup_telemetry_data.sh
chmod +x check_and_restore_containers.sh
chmod +x test_data_persistence.sh
chmod +x setup_automated_backup.sh
```

### 測試驗證

- 所有數據持久化測試通過
- 備份和恢復功能正常工作
- 容器重啟後數據完整保留

## 結論

✅ **系統已完全配置數據持久化**

- 所有 Docker volumes 正確配置並運行
- 完整的備份和恢復系統已建立
- 自動化備份和監控已設置
- 意外關閉後可完全恢復到之前狀態

系統現在具備完整的數據保護能力，可以安全地處理容器意外關閉的情況。
