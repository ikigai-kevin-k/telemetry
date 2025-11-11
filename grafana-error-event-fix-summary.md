# Grafana Error Event Dashboard 修復總結

## 問題描述

在將 `error_event.json` 加入 provisioning 後，Grafana 無法啟動，錯誤訊息：
```
got invalid response. expected folder, found dashboard
```

## 已完成的修復

### 1. 修正 JSON 檔案格式

已修正以下問題：
- ✅ `id`: 從 `56` 改為 `null`
- ✅ `uid`: 從 UUID 改為 `error-event-dashboard`
- ✅ `version`: 從 `4` 改為 `1`
- ✅ `timezone`: 從空字串改為 `"Asia/Taipei"`
- ✅ `annotations.datasource`: 從物件改為字串 `"-- Grafana --"`

### 2. 暫時解決方案

目前將 `error_event.json` 放在 `general` 資料夾中，這樣：
- ✅ Grafana 可以正常啟動
- ✅ Dashboard 會出現在 "Overview" folder 中
- ✅ 所有設定（包括隱藏欄位的 Transform）都會保留

## 當前狀態

- **檔案位置**: `grafana/provisioning/dashboards/general/error_event.json`
- **Dashboard Folder**: Overview
- **Dashboard UID**: `error-event-dashboard`
- **Grafana 狀態**: ✅ 正常運行

## 後續建議

### 選項 1: 保留在 Overview Folder（推薦）

如果不需要單獨的 "Error Event" folder，可以保持現狀：
- Dashboard 會出現在 "Overview" folder
- 所有功能正常運作
- 設定已持久化

### 選項 2: 建立獨立的 Error Event Folder

如果需要獨立的 folder，可以：

1. **檢查 Grafana 版本相容性**：
   ```bash
   docker exec kevin-telemetry-grafana grafana-server -v
   ```

2. **嘗試使用不同的 folder 名稱**：
   在 `dashboard.yml` 中使用不同的 folder 名稱，例如：
   ```yaml
   folder: 'ErrorEvents'  # 不使用空格
   ```

3. **檢查 JSON 檔案是否有特殊字元**：
   ```bash
   jq '.' grafana/provisioning/dashboards/error-event/error_event.json
   ```

## 驗證步驟

1. **檢查 Grafana 是否正常運行**：
   ```bash
   curl http://localhost:3000/api/health
   ```

2. **檢查 Dashboard 是否存在**：
   - 登入 Grafana (http://localhost:3000)
   - 前往 Dashboards → Browse
   - 檢查 "Overview" folder 中是否有 "Error Event" dashboard

3. **檢查 Panel 設定**：
   - 進入 Error Event dashboard
   - 確認只顯示 "Line" 欄位（其他欄位已隱藏）

## 相關檔案

- `grafana/provisioning/dashboards/general/error_event.json` - Dashboard JSON（當前位置）
- `grafana/provisioning/dashboards/error-event/error_event.json` - 原始位置（可刪除）
- `grafana/provisioning/dashboards/dashboard.yml` - Provisioning 配置

