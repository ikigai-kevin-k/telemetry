# 根目錄腳本索引

本文件列出專案根目錄中的所有 Shell 腳本及其用途。

## 📋 腳本分類

### 🚀 服務啟動與停止腳本（保留在根目錄）

#### 伺服器端啟動
- **`start-server.sh`** - 啟動伺服器模式
  - 用途：啟動 Loki Server、Zabbix Server/Web、Prometheus、Grafana
  - 支援：GE (100.64.0.113) 和 TPE (100.64.0.160) 伺服器
  - 用法：`./start-server.sh [ge|tpe]`

#### Agent 端啟動
- **`start-agent.sh`** - 啟動 Agent 模式
  - 用途：啟動 Promtail 和 Zabbix Agent
  - 功能：動態產生 agent 配置檔案
  - 用法：`./start-agent.sh <agent_name> <agent_ip>`
  - 範例：`./start-agent.sh GC-aro12-agent 100.64.0.149`
  - 依賴：`scripts/setup/generate-agent-configs.sh`

- **`start-asb-001-1-agent.sh`** - 啟動特定 Agent (ASB-001-1)
  - 用途：啟動特定 agent 的專用腳本

- **`start-test-agent.sh`** - 啟動測試 Agent
  - 用途：用於測試環境的 agent
  - 用法：`./start-test-agent.sh [ge|tpe]`
  - 注意：測試環境專用

#### 其他服務啟動
- **`start-webhook-service.sh`** - 啟動 Webhook 服務
- **`start-alertmanager.sh`** - 啟動 Alertmanager
- **`start-ebpf-exporter.sh`** - 啟動 eBPF Exporter
- **`start-network-monitor.sh`** - 啟動網路監控

#### 服務停止
- **`stop-ebpf-exporter.sh`** - 停止 eBPF Exporter
- **`stop-network-monitor.sh`** - 停止網路監控
- **`stop-test-agent.sh`** - 停止測試 Agent
- **`stop-webhook-service.sh`** - 停止 Webhook 服務

#### 服務重啟
- **`restart_aro_001_1_agent.sh`** - 重啟特定 Agent
- **`restart-grafana-with-credentials.sh`** - 使用憑證重啟 Grafana

### ⚡ 快捷指令腳本（Cursor Rules 中定義，保留在根目錄）

- **`codebase_line.sh`** - 程式碼行數統計腳本
  - 觸發指令：`[line]`
  - 用途：分析程式碼庫的程式碼行數統計

- **`query-loki-24h-growth.sh`** - Loki 儲存增長查詢腳本
  - 觸發指令：`[storage][loki]`
  - 用途：查詢過去 24 小時的 Loki 儲存增長分析

- **`query-prom-24h-growth.sh`** - Prometheus 儲存增長查詢腳本
  - 觸發指令：`[storage][prom]`
  - 用途：查詢過去 24 小時的 Prometheus 儲存增長分析

## 📁 其他腳本位置

### scripts/ 目錄

輔助腳本已整理到 `scripts/` 目錄，按功能分類：

#### scripts/setup/ - 配置腳本
- **`generate-agent-configs.sh`** - 產生 Agent 配置檔案
  - 用途：動態產生 Promtail 和 Zabbix Agent 配置
  - 被依賴：`start-agent.sh` 會呼叫此腳本
  - 用法：`./scripts/setup/generate-agent-configs.sh <agent_name> <agent_ip>`

#### scripts/maintenance/ - 維護腳本
- **`backup_telemetry_data.sh`** - 備份 Telemetry 資料
  - 用途：備份所有 Docker volumes 和配置檔案
  - 被依賴：`setup_automated_backup.sh` 會引用此腳本
  - 用法：`./scripts/maintenance/backup_telemetry_data.sh`

- **`setup_automated_backup.sh`** - 設定自動備份
  - 用途：設定 cron jobs 進行自動備份和健康檢查
  - 依賴：`backup_telemetry_data.sh`, `check_and_restore_containers.sh`
  - 用法：`./scripts/maintenance/setup_automated_backup.sh`

- **`check_and_restore_containers.sh`** - 檢查和恢復容器
  - 用途：檢查容器健康狀態並自動恢復
  - 被依賴：`setup_automated_backup.sh` 會引用此腳本
  - 用法：`./scripts/maintenance/check_and_restore_containers.sh`

- **`cleanup-journald.sh`** - 清理 systemd-journald 日誌
  - 用途：清理 systemd-journald 日誌，保留最近 30 天的記錄
  - 用法：`./scripts/maintenance/cleanup-journald.sh`

#### scripts/monitoring/ - 監控腳本
- **`monitor-alert-system.sh`** - 監控告警系統
  - 用途：監控 Alertmanager 和告警流程
  - 用法：`./scripts/monitoring/monitor-alert-system.sh`

- **`monitor-loki-storage.sh`** - 監控 Loki 儲存
  - 用途：監控 Loki 儲存使用情況
  - 用法：`./scripts/monitoring/monitor-loki-storage.sh`

- **`container_stats.sh`** - 容器統計
  - 用途：顯示容器資源使用統計
  - 用法：`./scripts/monitoring/container_stats.sh`

- **`list-agents.sh`** - 列出所有 Agents
  - 用途：列出所有已配置的 agents
  - 用法：`./scripts/monitoring/list-agents.sh`

#### scripts/dashboard/ - Dashboard 管理腳本
- **`apply_persistence.sh`** - 套用持久化配置
  - 用途：套用已匯出的 Dashboard 配置
  - 用法：`./scripts/dashboard/apply_persistence.sh`

- **`export_and_persist.sh`** - 匯出並持久化
  - 用途：匯出 Dashboard 配置並持久化
  - 用法：`./scripts/dashboard/export_and_persist.sh`

- **`persist_dashboard_panels.sh`** - 持久化 Dashboard 面板
  - 用途：將 Dashboard 面板配置持久化
  - 用法：`./scripts/dashboard/persist_dashboard_panels.sh`

#### scripts/helpers/ - 輔助腳本
其他輔助腳本請參考 `scripts/README.md`。

### archive/ 目錄
一次性測試腳本已整理到 `archive/` 目錄：
- `archive/tests/` - 測試腳本
- `archive/verifications/` - 驗證腳本
- `archive/diagnostics/` - 診斷腳本
- `archive/fixes/` - 修復腳本

## 🔍 快速查找

### 按用途查找

**啟動服務：**
```bash
./start-server.sh      # 啟動伺服器
./start-agent.sh       # 啟動 agent
./start-webhook-service.sh  # 啟動 webhook
```

**停止服務：**
```bash
./stop-test-agent.sh
./stop-webhook-service.sh
```

**查詢儲存：**
```bash
./query-loki-24h-growth.sh
./query-prom-24h-growth.sh
```

**備份資料：**
```bash
./scripts/maintenance/backup_telemetry_data.sh
./scripts/maintenance/setup_automated_backup.sh
```

**監控系統：**
```bash
./scripts/monitoring/monitor-alert-system.sh
./scripts/monitoring/monitor-loki-storage.sh
./scripts/monitoring/container_stats.sh
./scripts/monitoring/list-agents.sh
```

**Dashboard 管理：**
```bash
./scripts/dashboard/apply_persistence.sh
./scripts/dashboard/export_and_persist.sh
./scripts/dashboard/persist_dashboard_panels.sh
```

## 📚 相關文檔

- `sh_clean.md` - Shell 腳本整理分析報告
- `scripts/README.md` - scripts/ 目錄說明
- `README.md` - 專案主文檔

---

**最後更新：2026-01-20
