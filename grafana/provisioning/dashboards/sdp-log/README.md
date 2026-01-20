# SDP Log Dashboard 持久化設定

## 概述

此目錄包含 SDP Log dashboard 的持久化配置檔案。Dashboard 已從 "Error Event" 重新命名為 "SDP Log"。

## 當前狀態

- **Dashboard 標題**: SDP Log
- **Dashboard UID**: `sdp-log-dashboard`（或可能是原本的 `error-event-dashboard`）
- **檔案位置**: `grafana/provisioning/dashboards/sdp-log/sdp-log.json`
- **Dashboard Folder**: Dashboards

## 從 Grafana 匯出最新配置

由於您已經在 Grafana UI 中將 dashboard 重新命名為 "SDP Log"，建議從 Grafana 匯出最新的完整配置來確保所有設定都正確持久化。

### 步驟 1: 取得 Dashboard UID

1. 在 Grafana UI 中進入 **SDP Log** dashboard
2. 點擊右上角 **Settings**（齒輪圖示）
3. 在左側選單中選擇 **General**
4. 查看 **UID** 欄位（例如：`error-event-dashboard` 或 `sdp-log-dashboard`）

### 步驟 2: 取得 Grafana API Key

1. 前往 **Administration** → **Users and access** → **API keys**
2. 點擊 **New API key**
3. 設定：
   - **Name**: `export-dashboard`
   - **Role**: `Admin`
4. 複製產生的 API Key token

### 步驟 3: 匯出 Dashboard

```bash
# 設定 API Key
export GRAFANA_API_KEY="your-api-key-here"

# 匯出 dashboard（使用實際的 UID）
./scripts/export-grafana-dashboard.sh <dashboard-uid> sdp-log.json

# 例如，如果 UID 是 error-event-dashboard：
./scripts/export-grafana-dashboard.sh error-event-dashboard sdp-log.json

# 或如果 UID 是 sdp-log-dashboard：
./scripts/export-grafana-dashboard.sh sdp-log-dashboard sdp-log.json
```

腳本會自動：
- 從 Grafana 取得最新的 dashboard JSON（包含所有 panels 和設定）
- 清理不需要的欄位（id, version, created, updated 等）
- 保留標題 "SDP Log" 和所有 panel 配置
- 儲存到 `grafana/provisioning/dashboards/sdp-log/sdp-log.json`

### 步驟 4: 驗證匯出的配置

```bash
# 檢查 JSON 格式
jq '.' grafana/provisioning/dashboards/sdp-log/sdp-log.json

# 檢查標題是否為 "SDP Log"
jq -r '.title' grafana/provisioning/dashboards/sdp-log/sdp-log.json

# 檢查 UID
jq -r '.uid' grafana/provisioning/dashboards/sdp-log/sdp-log.json
```

### 步驟 5: 等待自動重新載入

Grafana 會每 10 秒自動檢查 provisioning 目錄，無需重啟容器。變更會在約 10-30 秒內自動套用。

如果需要立即套用，可以重啟 Grafana：

```bash
docker-compose restart grafana
```

## 驗證 Dashboard 載入

1. 等待約 10-30 秒讓 Grafana 重新載入 provisioning
2. 前往 **Dashboards** → **Browse**
3. 檢查是否有 **SDP Log** dashboard（在 "Dashboards" folder 中）
4. 進入 dashboard，確認：
   - 標題顯示為 "SDP Log"
   - 所有 panels 正常顯示
   - 所有設定（包括隱藏欄位的 Transform）都保留

## 注意事項

1. **UID 一致性**：
   - 確保 JSON 中的 `uid` 與 Grafana 中的 UID 一致
   - 如果 UID 不同，Grafana 會建立新的 dashboard 而不是更新現有的

2. **標題持久化**：
   - 匯出的 JSON 中的 `title` 欄位應該是 "SDP Log"
   - 這確保了重新命名會持久化儲存

3. **自動重新載入**：
   - Grafana 會每 10 秒檢查 provisioning 目錄
   - 變更會自動套用，無需重啟容器

4. **UI 更新**：
   - `dashboard.yml` 中設定了 `allowUiUpdates: true`
   - 這允許在 UI 中的變更與 provisioning 檔案同步

## 故障排除

### 問題 1: Dashboard 未出現或標題不正確

**解決方案**：
1. 確認已從 Grafana 匯出最新的配置
2. 檢查 JSON 中的 `title` 是否為 "SDP Log"
3. 檢查 `dashboard.yml` 配置是否正確
4. 查看 Grafana 日誌：
   ```bash
   docker-compose logs grafana | grep -i "provisioning\|sdp\|error"
   ```

### 問題 2: UID 不匹配

**解決方案**：
1. 在 Grafana UI 中查看實際的 UID
2. 更新 JSON 中的 `uid` 欄位
3. 或使用匯出腳本重新匯出

### 問題 3: Panels 或設定遺失

**解決方案**：
1. 使用匯出腳本重新匯出完整的 dashboard 配置
2. 確保匯出時包含所有 panels 和 transformations









