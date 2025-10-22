# Grafana Explore: GC-aro11-agent Network Monitor rx_bits 時間趨勢圖查詢指南

## 📋 查詢目標

**目標**: 在 Grafana Explore 中查詢 GC-aro11-agent 的 network_monitor log 中 rx_bits 的值並呈現時間趨勢圖  
**資料來源**: Loki  
**Agent**: GC-aro11-agent  
**欄位**: rx_bits (接收位元數)  

## 🔍 步驟 1: 開啟 Grafana Explore

1. **訪問 Grafana**: http://100.64.0.113:3000
2. **點擊左側選單的 'Explore' 圖示** (放大鏡圖示)
3. **選擇資料來源為 'Loki'**

## 📊 步驟 2: 基本查詢語法

### 2.1 基本標籤查詢
```
{job="network_monitor",instance="GC-aro11-agent"}
```

### 2.2 JSON 解析查詢
```
{job="network_monitor",instance="GC-aro11-agent"} | json
```

### 2.3 提取 rx_bits 欄位
```
{job="network_monitor",instance="GC-aro11-agent"} | json | rx_bits > 0
```

## 📈 步驟 3: 時間趨勢圖查詢

### 3.1 基本時間趨勢查詢
```
{job="network_monitor",instance="GC-aro11-agent"} | json | line_format "{{.rx_bits}}"
```

### 3.2 使用 unwrap 提取數值 (推薦)
```
sum by (interface) (unwrap rx_bits {job="network_monitor",instance="GC-aro11-agent"} | json)
```

### 3.3 計算速率 (每秒位元數)
```
rate(sum by (interface) (unwrap rx_bits {job="network_monitor",instance="GC-aro11-agent"} | json)[5m])
```

### 3.4 計算增量 (位元數變化)
```
increase(sum by (interface) (unwrap rx_bits {job="network_monitor",instance="GC-aro11-agent"} | json)[5m])
```

## ⚙️ 步驟 4: 查詢參數設定

### 4.1 時間範圍設定
- **建議時間範圍**: "Last 1 hour" 或 "Last 6 hours"
- **自定義時間範圍**: 根據需要設定

### 4.2 查詢類型設定
- **查詢類型**: Range (範圍查詢)
- **查詢限制**: 1000 (避免過多資料)

### 4.3 視圖模式設定
- **視圖模式**: Graph (圖表視圖)
- **顯示選項**: 啟用 "Time" 和 "Prettify JSON"

## 📊 步驟 5: 進階查詢語法

### 5.1 多介面支援查詢
```
sum by (interface) (unwrap rx_bits {job="network_monitor",instance="GC-aro11-agent"} | json)
```

### 5.2 過濾特定介面
```
sum by (interface) (unwrap rx_bits {job="network_monitor",instance="GC-aro11-agent",interface="enp86s0"} | json)
```

### 5.3 計算相對變化
```
sum by (interface) (unwrap rx_bits {job="network_monitor",instance="GC-aro11-agent"} | json) - sum by (interface) (unwrap rx_bits {job="network_monitor",instance="GC-aro11-agent"} | json offset 1m)
```

### 5.4 計算平均值
```
avg_over_time(sum by (interface) (unwrap rx_bits {job="network_monitor",instance="GC-aro11-agent"} | json)[5m])
```

## 🎯 步驟 6: 推薦查詢順序

### 6.1 測試基本查詢
```
{job="network_monitor",instance="GC-aro11-agent"}
```

### 6.2 測試 JSON 解析
```
{job="network_monitor",instance="GC-aro11-agent"} | json
```

### 6.3 測試數值提取
```
{job="network_monitor",instance="GC-aro11-agent"} | json | rx_bits > 0
```

### 6.4 測試時間趨勢
```
sum by (interface) (unwrap rx_bits {job="network_monitor",instance="GC-aro11-agent"} | json)
```

### 6.5 測試速率計算
```
rate(sum by (interface) (unwrap rx_bits {job="network_monitor",instance="GC-aro11-agent"} | json)[5m])
```

## 📈 步驟 7: 圖表配置

### 7.1 圖表類型設定
- **圖表類型**: Time series
- **Y軸標籤**: "RX Bits"
- **單位**: "bits" 或 "bits/sec"

### 7.2 圖例設定
- **圖例模式**: "List"
- **圖例位置**: "Bottom"
- **顯示**: interface 標籤

### 7.3 顏色和樣式
- **線條寬度**: 2px
- **填充**: 啟用 (透明度 10%)
- **點標記**: 啟用

## 🔧 步驟 8: 除錯技巧

### 8.1 檢查資料存在性
```
{job="network_monitor",instance="GC-aro11-agent"} | json | __error__=""
```

### 8.2 檢查欄位值
```
{job="network_monitor",instance="GC-aro11-agent"} | json | rx_bits != ""
```

### 8.3 檢查時間戳記
```
{job="network_monitor",instance="GC-aro11-agent"} | json | timestamp != ""
```

## 📋 步驟 9: 完整查詢範例

### 9.1 基本 rx_bits 趨勢圖
```
sum by (interface) (unwrap rx_bits {job="network_monitor",instance="GC-aro11-agent"} | json)
```

### 9.2 rx_bits 速率圖 (每秒位元數)
```
rate(sum by (interface) (unwrap rx_bits {job="network_monitor",instance="GC-aro11-agent"} | json)[5m])
```

### 9.3 rx_bits 增量圖 (位元數變化)
```
increase(sum by (interface) (unwrap rx_bits {job="network_monitor",instance="GC-aro11-agent"} | json)[5m])
```

### 9.4 rx_bits 平均值圖
```
avg_over_time(sum by (interface) (unwrap rx_bits {job="network_monitor",instance="GC-aro11-agent"} | json)[5m])
```

## 🎯 步驟 10: 成功指標

### 10.1 查詢成功指標
- ✅ 查詢返回資料
- ✅ JSON 解析成功
- ✅ rx_bits 欄位存在
- ✅ 時間戳記正確

### 10.2 圖表成功指標
- ✅ 時間趨勢圖正常顯示
- ✅ Y軸顯示正確的數值
- ✅ 圖例顯示 interface 標籤
- ✅ 資料點按時間順序排列

## 🔍 步驟 11: 常見問題排除

### 11.1 查詢沒有結果
**解決方案**:
- 檢查時間範圍設定
- 確認標籤名稱正確
- 嘗試更寬鬆的查詢條件

### 11.2 JSON 解析錯誤
**解決方案**:
- 先查看原始 log 格式
- 檢查 JSON 語法是否正確
- 使用 `| json | __error__=""` 過濾錯誤

### 11.3 圖表顯示異常
**解決方案**:
- 檢查 Y軸範圍設定
- 確認資料類型正確
- 調整圖表刷新間隔

## 📊 步驟 12: 進階功能

### 12.1 警報設定
```
rate(sum by (interface) (unwrap rx_bits {job="network_monitor",instance="GC-aro11-agent"} | json)[5m]) > 1000000000
```

### 12.2 儀表板變數
```
{job="network_monitor",instance="$instance",interface="$interface"} | json
```

### 12.3 註解設定
```
{job="network_monitor",instance="GC-aro11-agent"} | json | rx_bits > 0
```

## 📋 快速參考

### 關鍵查詢語法
```
# 基本查詢
{job="network_monitor",instance="GC-aro11-agent"}

# JSON 解析
{job="network_monitor",instance="GC-aro11-agent"} | json

# 數值提取
sum by (interface) (unwrap rx_bits {job="network_monitor",instance="GC-aro11-agent"} | json)

# 速率計算
rate(sum by (interface) (unwrap rx_bits {job="network_monitor",instance="GC-aro11-agent"} | json)[5m])
```

### 圖表配置
- **查詢類型**: Range
- **視圖模式**: Graph
- **時間範圍**: Last 1 hour
- **Y軸單位**: bits 或 bits/sec

### 成功指標
- ✅ 查詢返回 rx_bits 資料
- ✅ 時間趨勢圖正常顯示
- ✅ 數值按時間順序排列
- ✅ 圖例顯示正確的標籤

---

**指南完成時間**: 2025-10-22 07:30:00 AM +04  
**適用版本**: Grafana 9.5.21 + Loki  
**資料來源**: GC-aro11-agent network_monitor logs
