# Python 腳本索引

本文件列出專案中所有 Python 腳本及其用途和位置。

## 📋 腳本位置

### 根目錄（核心功能腳本）

#### 服務腳本
- **`grafana_webhook_service.py`** - Grafana Webhook 服務
  - **用途**：接收 Grafana 告警並觸發 API 呼叫
  - **功能**：
    - 接收 Grafana 告警 webhook
    - 當檢測到 `okbps=0,0,0` 時觸發 API 呼叫
    - 提供健康檢查端點 (`/health`)
  - **被依賴**：
    - `Dockerfile.webhook` - Docker 映像檔建置
    - `docker-compose.yml` - 容器配置
    - `start-webhook-service.sh` - 啟動腳本
  - **依賴套件**：Flask, requests
  - **端口**：5000
  - **健康檢查**：`http://localhost:5000/health`
  - **Webhook 端點**：`/webhook/grafana`
  - **狀態**：✅ **核心功能，必須保留**

#### 監控腳本
- **`network_monitor.py`** - 網路介面監控
  - **用途**：收集網路介面統計資料並寫入日誌檔案供 Promtail 收集
  - **功能**：
    - 從 `/proc/net/dev` 讀取網路介面統計
    - 將統計資料格式化為 JSON
    - 寫入日誌檔案供 Promtail 收集
  - **被依賴**：
    - `start-network-monitor.sh` - 啟動腳本
    - `stop-network-monitor.sh` - 停止腳本
    - `promtail-config.yml` - Promtail 配置（間接引用）
    - `promtail-GC-ARO-001-1-agent.yml` - Agent Promtail 配置（間接引用）
    - 多個診斷腳本和 Dashboard 配置引用
  - **輸出格式**：JSON
  - **預設介面**：enp86s0
  - **預設日誌檔案**：`/home/rnd/telemetry/logs/network_stats.log`
  - **狀態**：✅ **核心功能，必須保留**

### scripts/helpers/（輔助工具腳本）

- **`query_loki_logs.py`** - 查詢 Loki 日誌工具
  - **用途**：從遠端 Loki 伺服器查詢日誌
  - **功能**：
    - 查詢多種 LogQL 查詢
    - 顯示查詢結果
    - 用於診斷和驗證
  - **用法**：`python3 scripts/helpers/query_loki_logs.py`
  - **狀態**：⚠️ **診斷工具，可能定期使用**

### archive/tests/（測試腳本）

以下腳本已歸檔到 `archive/tests/` 目錄，用於測試和驗證：

1. **test_logging.py** - 測試日誌功能
2. **test_loki_push.py** - 測試 Loki 推送
3. **test_network_monitoring.py** - 測試網路監控
4. **test_sdp_regex.py** - 測試 SDP 正則表達式
5. **test_studio_sdp_logs.py** - 測試 Studio SDP 日誌
6. **continuous_log_test.py** - 持續日誌測試
7. **generate_sdp_logs.py** - 產生 SDP 日誌
8. **simple_sdp_log.py** - 簡單 SDP 日誌
9. **single_sdp_log.py** - 單一 SDP 日誌
10. **mock_main_sicbo.py** - 模擬 Sicbo 應用程式
11. **push_sdp_to_loki.py** - 推送 SDP 日誌到 Loki（測試工具）

### archive/diagnostics/（診斷腳本）

以下腳本已歸檔到 `archive/diagnostics/` 目錄：

1. **check_grafana_loki.py** - 檢查 Grafana Loki 連線

## 🔍 快速查找

### 按用途查找

**核心服務：**
```bash
# 啟動 Webhook 服務
./start-webhook-service.sh
# 或直接執行
python3 grafana_webhook_service.py
```

**監控功能：**
```bash
# 啟動網路監控
./start-network-monitor.sh
# 或直接執行
python3 network_monitor.py
```

**診斷工具：**
```bash
# 查詢 Loki 日誌
python3 scripts/helpers/query_loki_logs.py
```

## 📚 相關文檔

- `py_clean.md` - Python 腳本整理分析報告
- `SCRIPTS_INDEX.md` - Shell 腳本索引
- `README.md` - 專案主文檔

## 🔗 依賴關係

### 核心依賴鏈

```
start-webhook-service.sh
  └─> grafana_webhook_service.py

Dockerfile.webhook
  └─> grafana_webhook_service.py

docker-compose.yml
  └─> grafana_webhook_service.py (volume mount)

start-network-monitor.sh
  └─> network_monitor.py

promtail-config.yml
  └─> network_monitor.py (indirect, via log file)
```

## 📦 依賴套件

核心腳本所需的 Python 套件（見 `requirements.txt`）：
- Flask - Webhook 服務框架
- requests - HTTP 請求庫

## 🛠️ 開發與維護

### 修改核心腳本注意事項

1. **grafana_webhook_service.py**：
   - 修改後需要重新建置 Docker 映像檔
   - 或重啟 webhook 服務容器

2. **network_monitor.py**：
   - 修改後需要重啟網路監控服務
   - 確保日誌檔案路徑正確

### 測試腳本

所有測試腳本已移至 `archive/tests/`，如需使用可從該目錄執行。

---

**最後更新：2026-01-20
