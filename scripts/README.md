# Scripts 目錄說明

本目錄包含專案的輔助腳本，按功能分類存放。

## 目錄結構

### setup/ - 設定腳本
用於系統初始設定和配置的腳本。

- **generate-agent-configs.sh** - 產生 Agent 配置檔案
  - 用途：動態產生 Promtail 和 Zabbix Agent 配置
  - 被依賴：`start-agent.sh` 會呼叫此腳本
  - 用法：`./scripts/setup/generate-agent-configs.sh <agent_name> <agent_ip>`

- **setup-ghcr.sh** - GitHub Container Registry 設定
- **setup-byteplus-credentials.sh** - BytePlus 憑證設定

### maintenance/ - 維護腳本
用於系統維護和管理的腳本。

- **backup_telemetry_data.sh** - 備份 Telemetry 資料
  - 用途：備份所有 Docker volumes 和配置檔案
  - 用法：`./scripts/maintenance/backup_telemetry_data.sh`

- **setup_automated_backup.sh** - 設定自動備份
  - 用途：設定 cron jobs 進行自動備份和健康檢查
  - 用法：`./scripts/maintenance/setup_automated_backup.sh`

- **check_and_restore_containers.sh** - 檢查和恢復容器
  - 用途：檢查容器健康狀態並自動恢復
  - 用法：`./scripts/maintenance/check_and_restore_containers.sh`

- **cleanup-journald.sh** - 清理 systemd-journald 日誌
  - 用途：清理 systemd-journald 日誌，保留最近 30 天的記錄
  - 用法：`./scripts/maintenance/cleanup-journald.sh`

- **change_zabbix_password.sh** - 更改 Zabbix 密碼
- **check-byteplus-status.sh** - 檢查 BytePlus 狀態
- **manage_aro_001_1_volumes.sh** - 管理特定 Agent 的 Volumes
- **manage-grafana-persistence.sh** - 管理 Grafana 持久化
- **update_zabbix_datasource_ip.sh** - 更新 Zabbix 資料來源 IP

### monitoring/ - 監控腳本
用於系統監控和狀態查詢的腳本。

- **monitor-alert-system.sh** - 監控告警系統
  - 用途：監控 Alertmanager 和告警流程
  - 用法：`./scripts/monitoring/monitor-alert-system.sh`

- **monitor-loki-storage.sh** - 監控 Loki 儲存
  - 用途：監控 Loki 儲存使用情況
  - 用法：`./scripts/monitoring/monitor-loki-storage.sh`

- **container_stats.sh** - 容器統計
  - 用途：顯示容器資源使用統計
  - 用法：`./scripts/monitoring/container_stats.sh`

- **list-agents.sh** - 列出所有 Agents
  - 用途：列出所有已配置的 agents
  - 用法：`./scripts/monitoring/list-agents.sh`

### dashboard/ - Dashboard 管理腳本
用於 Grafana Dashboard 管理的腳本。

- **apply_persistence.sh** - 套用持久化配置
  - 用途：套用已匯出的 Dashboard 配置
  - 用法：`./scripts/dashboard/apply_persistence.sh`

- **export_and_persist.sh** - 匯出並持久化
  - 用途：匯出 Dashboard 配置並持久化
  - 用法：`./scripts/dashboard/export_and_persist.sh`

- **persist_dashboard_panels.sh** - 持久化 Dashboard 面板
  - 用途：將 Dashboard 面板配置持久化
  - 用法：`./scripts/dashboard/persist_dashboard_panels.sh`

### helpers/ - 輔助腳本
用於資料確認和輔助功能的腳本。

- **server_side_data_confirmation.sh** - 伺服器端資料確認
- **final_loki_check.sh** - 最終 Loki 檢查
- **temperature-slack-alert.sh** - 溫度 Slack 告警
- **slack_script.sh** - Slack 腳本

## 使用方式

所有腳本都可以從專案根目錄執行：

```bash
# 執行設定腳本
./scripts/setup/generate-agent-configs.sh <agent_name> <agent_ip>

# 執行維護腳本
./scripts/maintenance/backup_telemetry_data.sh
./scripts/maintenance/setup_automated_backup.sh

# 執行監控腳本
./scripts/monitoring/monitor-alert-system.sh
./scripts/monitoring/list-agents.sh

# 執行 Dashboard 管理腳本
./scripts/dashboard/apply_persistence.sh
./scripts/dashboard/export_and_persist.sh

# 執行輔助腳本
./scripts/helpers/server_side_data_confirmation.sh
```

## 核心腳本位置

核心功能腳本（啟動、停止、查詢等）保留在專案根目錄，包括：

- `start-server.sh`, `start-agent.sh` - 服務啟動
- `stop-*.sh`, `restart-*.sh` - 服務控制
- `query-*.sh`, `codebase_line.sh` - 快捷指令（Cursor Rules 定義）

詳細說明請參考根目錄的 `SCRIPTS_INDEX.md` 文檔。

## Python 腳本

### helpers/ 目錄中的 Python 腳本

- **query_loki_logs.py** - 查詢 Loki 日誌工具
  - 用途：從遠端 Loki 伺服器查詢日誌
  - 用法：`python3 scripts/helpers/query_loki_logs.py`

詳細說明請參考根目錄的 `PYTHON_SCRIPTS_INDEX.md` 文檔。

---

**最後更新：2026-01-20
