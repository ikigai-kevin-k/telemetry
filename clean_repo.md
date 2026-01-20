# 程式碼庫清理分析報告

## 分析日期
2025-01-XX

## 概述
本文件分析目前 uncommitted changes 中的檔案，分類為：
1. **核心檔案**：必須保留的關鍵配置與功能檔案
2. **有依賴性的檔案**：被其他檔案或系統依賴的檔案
3. **一次性測試腳本**：用於測試、驗證或一次性修復的腳本

---

## 一、核心檔案（必須保留）

### 1.1 專案配置檔案
- **`.gitignore`** - Git 忽略規則配置，控制版本控制範圍
- **`requirements.txt`** - Python 依賴套件清單，用於 CI/CD 和環境建置
- **`mkdocs.yml`** - MkDocs 文檔生成配置，用於自動化文檔部署

### 1.2 CI/CD 工作流
- **`.github/workflows/docs.yml`** - GitHub Actions 文檔自動部署工作流
  - 依賴：`requirements.txt`, `mkdocs.yml`
  - 用途：自動建置並部署文檔到 GitHub Pages

### 1.3 快捷指令腳本（Cursor Rules 中定義）
- **`codebase_line.sh`** - 程式碼行數統計腳本
  - 觸發指令：`[line]`
  - 用途：分析程式碼庫的程式碼行數統計
- **`query-loki-24h-growth.sh`** - Loki 儲存增長查詢腳本
  - 觸發指令：`[storage][loki]`
  - 用途：查詢過去 24 小時的 Loki 儲存增長分析
- **`query-prom-24h-growth.sh`** - Prometheus 儲存增長查詢腳本
  - 觸發指令：`[storage][prom]`
  - 用途：查詢過去 24 小時的 Prometheus 儲存增長分析

### 1.4 Grafana 儀表板配置
- **`grafana/provisioning/dashboards/general/development.json`** - 開發環境儀表板配置
- **`grafana/provisioning/dashboards/general/overview.json`** - 總覽儀表板配置
- **`grafana/provisioning/dashboards/sdp-log/README.md`** - SDP 日誌儀表板說明

### 1.5 核心功能腳本
- **`scripts/disk-usage-exporter.py`** - 磁碟使用監控導出器
  - 用途：監控系統磁碟使用情況並導出 Prometheus metrics
  - 依賴：可能被 docker-compose 或其他服務引用

---

## 二、有依賴性的檔案

### 2.1 Grafana 管理腳本（scripts/ 目錄）
這些腳本可能被其他腳本或工作流程引用，需要確認依賴關係：

#### 權限管理相關
- **`scripts/backup-grafana-permissions.sh`** - Grafana 權限備份
- **`scripts/check-dashboard-permissions.sh`** - 儀表板權限檢查
- **`scripts/create-grafana-user.sh`** - 建立 Grafana 使用者
- **`scripts/verify-grafana-permissions-persistence.sh`** - 驗證權限持久化

#### 資料夾管理相關
- **`scripts/create-general-folder.sh`** - 建立 General 資料夾
- **`scripts/delete-empty-folder.sh`** - 刪除空資料夾
- **`scripts/delete-and-rename-general-folder.sh`** - 刪除並重新命名 General 資料夾
- **`scripts/delete-general-and-rename.sh`** - 刪除 General 並重新命名
- **`scripts/rename-folder.sh`** - 重新命名資料夾
- **`scripts/rename-generaldashboards-directly.sh`** - 直接重新命名 General 儀表板

#### 儀表板管理相關
- **`scripts/move-dashboards-to-folder.sh`** - 移動儀表板到資料夾
- **`scripts/move-dashboards-to-general.sh`** - 移動儀表板到 General
- **`scripts/move-dashboards-to-general-folder0.sh`** - 移動儀表板到 General Folder0
- **`scripts/list-grafana-resources.sh`** - 列出 Grafana 資源

#### 手動操作腳本
- **`scripts/manual-delete-general-and-rename.sh`** - 手動刪除並重新命名

**注意**：這些腳本之間可能有執行順序依賴，建議檢查是否有工作流程文檔說明執行順序。

### 2.2 文檔檔案（.md）
這些文檔可能被其他文檔、腳本或工作流程引用：

#### Grafana 相關文檔
- **`check-viewer-permissions-guide.md`** - 查看者權限指南
- **`grafana-error-event-fix-summary.md`** - Grafana 錯誤事件修復摘要
- **`grafana-extract-json-fields-guide.md`** - Grafana JSON 欄位提取指南
- **`grafana-extract-json-fields-quick-guide.md`** - Grafana JSON 欄位提取快速指南
- **`grafana-permissions-persistence.md`** - Grafana 權限持久化說明
- **`grafana-restrict-dashboard-access.md`** - Grafana 限制儀表板存取說明
- **`grafana-user-permissions.md`** - Grafana 使用者權限說明

#### 系統配置文檔
- **`docker_volume.md`** - Docker 卷配置說明
- **`zabbix_storage.md`** - Zabbix 儲存配置說明

#### 範例 JSON 檔案
- **`grafana-extract-json-fields-example.json`** - JSON 欄位提取範例
  - 可能被文檔引用作為範例

---

## 三、一次性測試腳本（可考慮清理）

### 3.1 測試腳本（test_*.sh）
這些腳本用於測試特定功能，測試完成後通常不再需要：

- **`test_disk_usage_exporter.sh`** - 測試磁碟使用導出器
  - 用途：驗證 disk-usage-exporter 是否正常運作
  - 建議：測試完成後可移除或移至 `tests/` 目錄

- **`test_network_data_ingestion.sh`** - 測試網路資料攝取
  - 用途：模擬網路監控資料並驗證 Loki 攝取
  - 建議：測試完成後可移除

- **`test_loki_datasources.sh`** - 測試 Loki 資料來源
  - 用途：檢查哪個 Loki datasource 包含特定資料
  - 建議：診斷完成後可移除

- **`test_network_monitoring_setup.sh`** - 測試網路監控設定
  - 用途：驗證 GC-ARO-001-1 agent 的網路監控設定
  - 建議：設定完成後可移除

### 3.2 驗證腳本（*_verification.sh）
這些腳本用於驗證特定修復或變更，驗證完成後通常不再需要：

- **`agent_label_verification.sh`** - Agent 標籤更新驗證
- **`agent_label_fix_verification.sh`** - Agent 標籤修復驗證
- **`zcam_label_verification.sh`** - ZCAM 標籤驗證
- **`zcam_legend_fix_verification.sh`** - ZCAM 圖例修復驗證
- **`zcam_prefix_fix_verification.sh`** - ZCAM 前綴修復驗證
- **`zcam_uppercase_verification.sh`** - ZCAM 大寫驗證

### 3.3 修復腳本（*_fix.sh）
這些腳本用於一次性修復特定問題，修復完成後通常不再需要：

- **`fix-duplicate-legend.sh`** - 修復重複圖例
- **`fix-error-event-panel.sh`** - 修復錯誤事件面板
- **`simple_uppercase_fix.sh`** - 簡單大寫修復
- **`correct_uppercase_fix.sh`** - 正確大寫修復
- **`final_uppercase_fix.sh`** - 最終大寫修復

### 3.4 診斷與檢查腳本
這些腳本用於一次性診斷或檢查，完成後通常不再需要：

- **`check-error-event-metrics.sh`** - 檢查錯誤事件指標
- **`check-tableapi_instances.sh`** - 檢查 TableAPI 實例
- **`server_side_loki_diagnosis.sh`** - 伺服器端 Loki 診斷

### 3.5 網路監控相關腳本（可能是一次性）
這些腳本可能用於特定環境的設定或測試：

- **`get_all_network_metrics.sh`** - 取得所有網路指標
- **`get_gc_aro_001_1_network_metrics.sh`** - 取得 GC-ARO-001-1 網路指標
- **`get_network_metrics_accurate.sh`** - 取得準確網路指標
- **`get_network_metrics_final.sh`** - 取得最終網路指標
- **`get_network_metrics_simple.sh`** - 取得簡單網路指標

**注意**：如果這些腳本用於定期監控，則應保留；如果只是用於一次性測試，可考慮移除。

### 3.6 設定與指南腳本（可能是一次性）
這些腳本可能用於特定環境的設定：

- **`alias_setting_guide.sh`** - 別名設定指南
- **`detailed_alias_guide.sh`** - 詳細別名指南
- **`complete_workflow_guide.sh`** - 完整工作流程指南
- **`manual_edit_guide.sh`** - 手動編輯指南
- **`zcam_manual_fix_guide.sh`** - ZCAM 手動修復指南

### 3.7 系統設定腳本（可能是一次性）
- **`convert_shm_to_xfs.sh`** - 轉換 SHM 到 XFS 檔案系統
  - 用途：一次性系統設定
  - 建議：設定完成後可移除或移至 `scripts/archive/` 目錄

### 3.8 Zabbix 相關腳本
- **`zabbix/create_alias_interface_items.sh`** - 建立別名介面項目
- **`zabbix/provision_hosts_like_ARO11.sh`** - 佈署類似 ARO11 的主機
- **`zabbix/sync_like_ARO11_all_agents.sh`** - 同步類似 ARO11 的所有 agents

**注意**：如果這些腳本用於定期維護，則應保留；如果只是用於一次性設定，可考慮移除。

### 3.9 其他一次性腳本
- **`query-loki-hourly-growth.sh`** - 查詢 Loki 每小時增長
  - 注意：與 `query-loki-24h-growth.sh` 類似，但可能是一次性查詢需求
- **`grafana-aro11-message-transform-example.json`** - Grafana ARO11 訊息轉換範例
  - 可能是一次性參考範例

### 3.10 備份與臨時檔案
- **`grafana/provisioning/dashboards/general/development.json.backup.20251129_121432`** - 備份檔案
- **`grafana/provisioning/dashboards/general/development.json.backup.20251129_121532`** - 備份檔案
- **`backups/`** - 備份目錄（整個目錄）
- **`exported_dashboard.json`** - 匯出的儀表板（可能是臨時檔案）

---

## 四、依賴關係分析

### 4.1 核心依賴鏈
```
.github/workflows/docs.yml
  └─> requirements.txt
  └─> mkdocs.yml
      └─> docs/ 目錄（如果存在）

codebase_line.sh (快捷指令)
query-loki-24h-growth.sh (快捷指令)
query-prom-24h-growth.sh (快捷指令)
```

### 4.2 Grafana 腳本依賴關係
Grafana 管理腳本之間可能有執行順序依賴，建議檢查：
- 建立資料夾 → 移動儀表板 → 設定權限
- 備份權限 → 修改權限 → 驗證權限

### 4.3 文檔依賴關係
- 文檔檔案可能互相引用（需要檢查內部連結）
- JSON 範例檔案可能被文檔引用

---

## 五、清理建議

### 5.1 立即清理（一次性測試腳本）
建議移至 `archive/` 或 `tests/archive/` 目錄，或直接刪除：

1. **測試腳本**：
   - `test_*.sh` 所有檔案

2. **驗證腳本**：
   - `*_verification.sh` 所有檔案

3. **修復腳本**（如果修復已完成）：
   - `*_fix.sh` 所有檔案

4. **備份檔案**：
   - `*.backup.*` 所有檔案
   - `backups/` 目錄（如果不再需要）

### 5.2 評估後清理（可能的一次性腳本）
需要確認用途後決定：

1. **網路監控腳本**：
   - 如果只是用於測試，可移除
   - 如果用於定期監控，應保留

2. **設定指南腳本**：
   - 如果只是臨時指南，可移除
   - 如果作為文檔參考，應保留並移至 `docs/` 目錄

3. **Zabbix 腳本**：
   - 如果只是用於一次性設定，可移除
   - 如果用於定期維護，應保留

### 5.3 保留但整理
1. **Grafana 管理腳本**：
   - 保留在 `scripts/` 目錄
   - 建議建立 `scripts/README.md` 說明各腳本用途與執行順序

2. **文檔檔案**：
   - 保留所有 `.md` 文檔
   - 建議整理到 `docs/` 目錄結構中

3. **範例 JSON**：
   - 保留範例檔案
   - 建議移至 `examples/` 或 `docs/examples/` 目錄

---

## 六、檔案統計

### 6.1 核心檔案
- 總數：約 10-12 個檔案
- 狀態：**必須保留**

### 6.2 有依賴性的檔案
- Grafana 腳本：約 15 個
- 文檔檔案：約 10 個
- 狀態：**需要評估依賴關係後決定**

### 6.3 一次性測試腳本
- 測試腳本：約 4 個
- 驗證腳本：約 6 個
- 修復腳本：約 5 個
- 診斷腳本：約 3 個
- 網路監控腳本：約 5 個
- 其他一次性腳本：約 10 個
- 備份檔案：約 3 個
- 總數：約 36-40 個檔案
- 狀態：**建議清理或歸檔**

---

## 七、執行建議

### 7.1 立即行動
1. 建立 `archive/` 目錄
2. 移動所有 `test_*.sh` 到 `archive/tests/`
3. 移動所有 `*_verification.sh` 到 `archive/verifications/`
4. 移動所有 `*_fix.sh` 到 `archive/fixes/`（如果修復已完成）
5. 刪除所有 `.backup.*` 檔案

### 7.2 評估後行動
1. 檢查網路監控腳本的使用頻率
2. 檢查 Zabbix 腳本的使用頻率
3. 整理文檔到 `docs/` 目錄結構
4. 建立 `scripts/README.md` 說明腳本用途

### 7.3 長期維護
1. 建立 `tests/` 目錄存放可重複使用的測試腳本
2. 建立 `scripts/archive/` 目錄存放舊版或一次性腳本
3. 定期檢查並清理 `archive/` 目錄

---

## 八、注意事項

1. **備份**：在執行任何清理操作前，請先備份整個專案
2. **Git 歷史**：即使刪除檔案，Git 歷史中仍會保留記錄
3. **依賴檢查**：刪除前請確認沒有其他檔案或腳本引用這些檔案
4. **文檔更新**：如果刪除文檔，請確認沒有其他文檔引用它們
5. **CI/CD**：確認刪除的檔案不會影響 CI/CD 流程

---

## 附錄：檔案清單

### 核心檔案清單
```
.gitignore
requirements.txt
mkdocs.yml
.github/workflows/docs.yml
codebase_line.sh
query-loki-24h-growth.sh
query-prom-24h-growth.sh
scripts/disk-usage-exporter.py
grafana/provisioning/dashboards/general/development.json
grafana/provisioning/dashboards/general/overview.json
grafana/provisioning/dashboards/sdp-log/README.md
```

### 有依賴性檔案清單（Grafana 腳本）
```
scripts/backup-grafana-permissions.sh
scripts/check-dashboard-permissions.sh
scripts/create-general-folder.sh
scripts/create-grafana-user.sh
scripts/delete-and-rename-general-folder.sh
scripts/delete-empty-folder.sh
scripts/delete-general-and-rename.sh
scripts/list-grafana-resources.sh
scripts/manual-delete-general-and-rename.sh
scripts/move-dashboards-to-folder.sh
scripts/move-dashboards-to-general-folder0.sh
scripts/move-dashboards-to-general.sh
scripts/rename-folder.sh
scripts/rename-generaldashboards-directly.sh
scripts/verify-grafana-permissions-persistence.sh
```

### 一次性測試腳本清單
```
test_disk_usage_exporter.sh
test_network_data_ingestion.sh
test_loki_datasources.sh
test_network_monitoring_setup.sh
agent_label_verification.sh
agent_label_fix_verification.sh
zcam_label_verification.sh
zcam_legend_fix_verification.sh
zcam_prefix_fix_verification.sh
zcam_uppercase_verification.sh
fix-duplicate-legend.sh
fix-error-event-panel.sh
simple_uppercase_fix.sh
correct_uppercase_fix.sh
final_uppercase_fix.sh
check-error-event-metrics.sh
check_tableapi_instances.sh
server_side_loki_diagnosis.sh
get_all_network_metrics.sh
get_gc_aro_001_1_network_metrics.sh
get_network_metrics_accurate.sh
get_network_metrics_final.sh
get_network_metrics_simple.sh
alias_setting_guide.sh
detailed_alias_guide.sh
complete_workflow_guide.sh
manual_edit_guide.sh
zcam_manual_fix_guide.sh
convert_shm_to_xfs.sh
query-loki-hourly-growth.sh
zabbix/create_alias_interface_items.sh
zabbix/provision_hosts_like_ARO11.sh
zabbix/sync_like_ARO11_all_agents.sh
grafana-aro11-message-transform-example.json
exported_dashboard.json
```

---

**報告結束**

