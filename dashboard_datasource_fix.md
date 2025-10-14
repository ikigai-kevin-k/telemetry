# Dashboard "No Data" 問題根本修復報告

## 🔍 問題根本原因

經過深入檢查，我發現了 Dashboard 顯示 "No data" 的根本原因：

**Dashboard 配置中的 targets 缺少 `datasource` 設定**

### 問題分析
- ✅ **資料來源配置正確**: `byteplus-vmp-prometheus` UID 正確
- ✅ **Explore 查詢正常**: 可以正常查詢 `video_stutter`
- ✅ **時間範圍正確**: 6小時內有資料
- ❌ **Dashboard targets 缺少 datasource**: 這是關鍵問題！

## 🛠️ 修復內容

### 1. **修復前 vs 修復後對比**

**修復前 (錯誤配置)**:
```json
{
  "expr": "video_stutter",
  "refId": "A",
  "legendFormat": "{{client_ip}} - {{server_ip}} ({{ua_family}})",
  // 缺少 datasource 設定！
}
```

**修復後 (正確配置)**:
```json
{
  "expr": "video_stutter",
  "refId": "A",
  "legendFormat": "{{client_ip}} - {{server_ip}} ({{ua_family}})",
  "datasource": {
    "type": "prometheus",
    "uid": "byteplus-vmp-prometheus"
  }
}
```

### 2. **修復的檔案**

#### 主要 Dashboard: `byteplus-prometheus.json`
- ✅ 修復了 3 個面板的所有 targets
- ✅ 每個 target 都新增了正確的 `datasource` 設定
- ✅ 總共修復了 6 個 targets

#### 測試 Dashboard: `video-stutter-test.json`
- ✅ 修復了 1 個面板的 target
- ✅ 新增了正確的 `datasource` 設定

### 3. **修復的 Targets 詳情**

| 面板 | Target | 查詢 | 修復狀態 |
|------|--------|------|----------|
| Video Stutter - All Metrics | A | `video_stutter` | ✅ 已修復 |
| Video Stutter - By Client IP | A | `video_stutter{client_ip="127.0.0.1"}` | ✅ 已修復 |
| Video Stutter - By Client IP | B | `video_stutter{client_ip="185.104.192.73"}` | ✅ 已修復 |
| Video Stutter - By Server IP | A | `video_stutter{server_ip="103.4.201.163"}` | ✅ 已修復 |
| Video Stutter - By Server IP | B | `video_stutter{server_ip="169.150.215.184"}` | ✅ 已修復 |
| Video Stutter - By Server IP | C | `video_stutter{server_ip="169.150.215.185"}` | ✅ 已修復 |
| Video Stutter Test | A | `video_stutter` | ✅ 已修復 |

## 🔄 部署狀態

### 服務重啟
```bash
$ docker compose restart grafana
Container kevin-telemetry-grafana  Restarting
Container kevin-telemetry-grafana  Started
```

### 配置驗證
```bash
$ docker exec kevin-telemetry-grafana cat /etc/grafana/provisioning/dashboards/byteplus/byteplus-prometheus.json | jq '.panels[0].targets[0] | {expr, refId, datasource}'

{
  "expr": "video_stutter",
  "refId": "A",
  "datasource": {
    "type": "prometheus",
    "uid": "byteplus-vmp-prometheus"
  }
}
```

## 🌐 驗證步驟

### 1. 立即檢查
1. **重新載入 Dashboard 頁面**: 按 F5 或 Ctrl+R
2. **檢查 Video Stutter 面板**: 應該顯示資料而非 "No data"
3. **確認資料顯示**: 應該看到與 Explore 頁面相同的時間序列資料

### 2. 測試順序
1. **先測試**: "Video Stutter Test Dashboard" (簡化版本)
2. **再測試**: "BytePlus Prometheus Dashboard" (完整版本)
3. **確認所有面板**: 3 個面板都應該顯示資料

### 3. 預期結果
- ✅ **Video Stutter - All Metrics**: 顯示所有 `video_stutter` 指標
- ✅ **Video Stutter - By Client IP**: 顯示按客戶端 IP 分類的資料
- ✅ **Video Stutter - By Server IP**: 顯示按伺服器 IP 分類的資料

## 🔍 技術說明

### 為什麼會出現這個問題？

1. **Grafana Dashboard 配置結構**:
   - 面板層級有 `datasource` 設定
   - 每個 target 層級也需要 `datasource` 設定
   - 如果 target 層級缺少 `datasource`，會導致查詢失敗

2. **Explore vs Dashboard 差異**:
   - **Explore**: 直接在查詢編輯器中選擇資料來源
   - **Dashboard**: 需要在配置檔案中明確指定每個 target 的資料來源

3. **錯誤表現**:
   - 查詢語法正確，但沒有指定資料來源
   - Grafana 無法知道要從哪個資料來源執行查詢
   - 結果顯示 "No data"

## 📋 修復檢查清單

- [x] 比較 Explore 和 Dashboard 的查詢語法
- [x] 檢查資料來源 UID 是否正確
- [x] 驗證 Dashboard 配置是否正確載入
- [x] 發現 targets 缺少 datasource 設定
- [x] 修復所有面板的 targets 配置
- [x] 修復測試 Dashboard 配置
- [x] 重啟 Grafana 服務
- [x] 驗證配置檔案載入
- [x] 建立修復報告文件

## 🎯 預期結果

修復後，您應該能夠在 Dashboard 中看到：

- ✅ **完整的時間序列資料**: 與 Explore 頁面完全一致
- ✅ **多維度監控**: 按客戶端和伺服器 IP 分類顯示
- ✅ **正確的圖例**: 顯示 `{{client_ip}} - {{server_ip}} ({{ua_family}})` 格式
- ✅ **即時更新**: 30秒更新間隔正常工作
- ✅ **閾值顯示**: 綠色(0-5), 黃色(5-15), 紅色(>15)

## 🚨 重要提醒

**這是 Dashboard 配置的關鍵修復**，現在每個 target 都有正確的 `datasource` 設定，應該能夠正常顯示資料。

**請立即重新載入 Dashboard 頁面進行測試！**

---
*修復完成時間: 2024年10月14日 17:48*
*狀態: 根本問題已修復，等待用戶驗證*
