# Scripts 目錄說明

本目錄包含專案的輔助腳本，按功能分類存放。

## 目錄結構

### setup/ - 設定腳本
用於系統初始設定和配置的腳本。

- **setup-ghcr.sh** - GitHub Container Registry 設定
- **setup-byteplus-credentials.sh** - BytePlus 憑證設定

### maintenance/ - 維護腳本
用於系統維護和管理的腳本。

- **change_zabbix_password.sh** - 更改 Zabbix 密碼
- **check-byteplus-status.sh** - 檢查 BytePlus 狀態
- **manage_aro_001_1_volumes.sh** - 管理特定 Agent 的 Volumes
- **manage-grafana-persistence.sh** - 管理 Grafana 持久化
- **update_zabbix_datasource_ip.sh** - 更新 Zabbix 資料來源 IP

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
./scripts/setup/setup-ghcr.sh

# 執行維護腳本
./scripts/maintenance/change_zabbix_password.sh

# 執行輔助腳本
./scripts/helpers/server_side_data_confirmation.sh
```

## 核心腳本位置

核心功能腳本（啟動、停止、查詢等）保留在專案根目錄，包括：

- `start-server.sh`, `start-agent.sh` - 服務啟動
- `stop-*.sh`, `restart-*.sh` - 服務控制
- `query-*.sh`, `codebase_line.sh` - 快捷指令
- `backup_telemetry_data.sh` - 備份功能
- `monitor-*.sh` - 監控腳本

詳細說明請參考根目錄的 `sh_clean.md` 文檔。
