# Dashboard "No Data" 問題修復報告

## 🔍 問題診斷

您遇到的問題是：在 Grafana Explore 頁面可以正常查詢到 `video_stutter` 資料，但在 Dashboard 中顯示 "No data"。

## 🛠️ 已修復的問題

### 1. **Dashboard 配置重複問題**
**問題**: Dashboard 配置檔案中有重複的 `datasource` 和 `expr` 設定
```json
// 錯誤的配置 (重複設定)
{
  "expr": "video_stutter",
  "datasource": {
    "type": "prometheus",
    "uid": "byteplus-vmp-prometheus"
  },
  "expr": "video_stutter",  // 重複！
  "datasource": {           // 重複！
    "type": "prometheus",
    "uid": "byteplus-vmp-prometheus"
  }
}
```

**修復**: 移除重複的設定，保持乾淨的配置
```json
// 正確的配置
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

### 2. **查詢配置優化**
- ✅ 移除重複的 `datasource` 設定
- ✅ 移除重複的 `expr` 設定
- ✅ 保持正確的 `refId` 設定
- ✅ 優化圖例格式

### 3. **建立測試 Dashboard**
建立了 `video-stutter-test.json` 作為簡化版本來測試資料來源連線。

## 📊 修復後的 Dashboard 配置

### 主要 Dashboard: `byteplus-prometheus.json`
包含 3 個面板：
1. **Video Stutter - All Metrics**: 顯示所有 `video_stutter` 指標
2. **Video Stutter - By Client IP**: 按客戶端 IP 分類
3. **Video Stutter - By Server IP**: 按伺服器 IP 分類

### 測試 Dashboard: `video-stutter-test.json`
簡化的單一面板配置，用於驗證資料來源連線。

## 🔄 部署狀態

### 服務重啟
```bash
$ docker compose restart grafana
Container kevin-telemetry-grafana  Restarting
Container kevin-telemetry-grafana  Started
```

### 配置檔案更新
- ✅ 修復了 `byteplus-prometheus.json` 的重複配置問題
- ✅ 建立了 `video-stutter-test.json` 測試 Dashboard
- ✅ 配置檔案已載入到容器內

## 🌐 驗證步驟

### 1. 檢查 Dashboard 列表
1. 開啟 Grafana: `http://localhost:3000`
2. 登入: `admin/admin`
3. 導航至: `Home > Dashboards`
4. 確認以下 Dashboard 存在：
   - **BytePlus Prometheus Dashboard** (主要 Dashboard)
   - **Video Stutter Test Dashboard** (測試 Dashboard)

### 2. 測試資料顯示
1. 開啟 "Video Stutter Test Dashboard"
2. 確認面板顯示資料而非 "No data"
3. 如果測試 Dashboard 正常，則開啟主要 Dashboard

### 3. 檢查資料來源狀態
1. 導航至: `Home > Administration > Data sources`
2. 確認 "BP-VMP" 資料來源狀態為 "Data source is working"
3. 點擊 "Save & Test" 確認連線正常

## 🔧 如果問題仍然存在

### 檢查步驟
1. **確認資料來源連線**:
   ```bash
   # 檢查資料來源配置
   docker exec kevin-telemetry-grafana cat /etc/grafana/provisioning/datasources/byteplus-vmp.yml
   ```

2. **檢查 Dashboard 配置**:
   ```bash
   # 檢查 Dashboard 配置
   docker exec kevin-telemetry-grafana cat /etc/grafana/provisioning/dashboards/byteplus/byteplus-prometheus.json
   ```

3. **檢查 Grafana 日誌**:
   ```bash
   # 查看最近的錯誤日誌
   docker logs kevin-telemetry-grafana --tail 50
   ```

### 可能的其他原因
1. **時間範圍問題**: Dashboard 的時間範圍可能與資料可用時間不匹配
2. **查詢語法問題**: 雖然 Explore 可以工作，但 Dashboard 查詢可能有細微差異
3. **資料來源權限**: Dashboard 可能沒有正確的資料來源權限

## 📋 修復檢查清單

- [x] 診斷 Dashboard "No data" 問題
- [x] 檢查資料來源連線狀態
- [x] 修復 Dashboard 配置重複問題
- [x] 建立測試 Dashboard
- [x] 重啟 Grafana 服務
- [x] 驗證配置檔案載入
- [x] 建立修復報告文件

## 🎯 預期結果

修復後，您應該能夠在 Dashboard 中看到：
- ✅ **Video Stutter 資料**: 與 Explore 頁面相同的資料
- ✅ **多面板顯示**: 按客戶端和伺服器 IP 分類的資料
- ✅ **即時更新**: 30秒更新間隔
- ✅ **正確圖例**: 顯示 client_ip 和 server_ip 標籤

## 🔍 下一步

如果修復後仍有問題，請：
1. 先檢查 "Video Stutter Test Dashboard" 是否正常
2. 確認 Explore 頁面的查詢語法與 Dashboard 完全一致
3. 檢查 Dashboard 的時間範圍設定
4. 查看 Grafana 瀏覽器控制台的錯誤訊息

---
*修復完成時間: 2024年10月14日 17:42*
*狀態: Dashboard 配置已修復，等待驗證結果*
