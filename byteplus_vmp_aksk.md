# BytePlus VMP AK/SK 在 Grafana 中的設定指南

## 概述
本文件說明如何在 Grafana 中設定 BytePlus VMP 的 Access Key (AK) 和 Secret Key (SK) 來連接 Prometheus 資料來源。

## 前置條件
- 已取得 BytePlus IAM 的 Access Key (AK) 和 Secret Key (SK)
- 已安裝並運行 Grafana
- 具有 Prometheus 端點 URL

## 設定步驟

### 1. 進入 Grafana 資料來源設定
1. 登入 Grafana 管理介面
2. 導航至：`Home > Administration > Data sources`
3. 點擊 "Add data source" 或編輯現有的 Prometheus 資料來源

### 2. 基本設定
- **Type**: 選擇 "Prometheus"
- **Name**: 輸入資料來源名稱（例如：BP-VMP）
- **URL**: 輸入 Prometheus 端點
  ```
  https://query.prometheus-cn-hongkong.bytepluses.com/workspaces/be727a2b-8531-43db-8f55-233ce46dcec8
  ```

### 3. 認證設定 (Auth 區段)
在 Auth 區段中進行以下設定：

#### 啟用 Basic Authentication
1. **啟用 "Basic auth"**
   - 將 "Basic auth" 選項的開關切換為開啟狀態

2. **啟用 "With Credentials"**
   - 將 "With Credentials" 選項的開關切換為開啟狀態
   - 此選項確保認證資訊被正確傳送

3. **輸入認證資訊**
   - **Username 欄位**: 輸入您的 Access Key (AK)
   - **Password 欄位**: 輸入您的 Secret Key (SK)

### 4. 其他建議設定
- **Timeout**: 建議設定為 30-60 秒
- **Skip TLS Verify**: 根據您的環境需求決定是否啟用

### 5. 測試連線
1. 點擊 "Save & Test" 按鈕
2. 確認連線狀態顯示為成功
3. 檢查是否出現 "Alerting supported" 的綠色提示

## 驗證步驟
1. 確認資料來源狀態為 "Data source is working"
2. 嘗試建立一個簡單的查詢來測試資料存取
3. 檢查 Grafana 日誌中是否有認證相關的錯誤訊息

## 常見問題排除

### 認證失敗
- 確認 AK/SK 是否正確輸入
- 檢查 BytePlus IAM 中的權限設定
- 確認 Prometheus 端點 URL 是否正確

### 連線超時
- 檢查網路連線
- 增加 Timeout 設定值
- 確認防火牆設定

### TLS 錯誤
- 根據環境需求啟用/停用 "Skip TLS Verify"
- 檢查 SSL 憑證是否有效

## 安全注意事項
- 妥善保管 AK/SK 憑證
- 定期輪換 Access Key
- 遵循最小權限原則設定 IAM 權限
- 考慮使用環境變數或密鑰管理服務來儲存敏感資訊

## 相關資源
- [BytePlus VMP 官方文件](https://www.byteplus.com/)
- [Grafana Prometheus 資料來源文件](https://grafana.com/docs/grafana/latest/datasources/prometheus/)
- [BytePlus IAM 權限管理](https://www.byteplus.com/docs/iam/)

---
*文件建立日期: 2024年*
*最後更新: 2024年*
