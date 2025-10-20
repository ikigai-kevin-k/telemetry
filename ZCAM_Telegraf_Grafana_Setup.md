# ZCAM Telegraf + Grafana HTTP Response Monitoring Setup

## 📋 概述
本指南說明如何使用 Telegraf 的 `http_response` 插件配合 Grafana 建立 ZCAM API 監控 dashboard，基於 [Grafana HTTP Response Monitoring Dashboard](https://grafana.com/grafana/dashboards/11777-http-response-monitoring/) 的方法。

## 🏗️ 架構說明

```
ZCAM Devices (5台) → Telegraf (http_response plugin) → Prometheus → Grafana Dashboard
```

### 組件說明
- **Telegraf**: 使用 `http_response` 插件監控 ZCAM API 端點
- **Prometheus**: 收集 Telegraf 產生的 metrics
- **Grafana**: 視覺化 HTTP response 監控資料

## 📁 建立的檔案

### 1. **Telegraf 配置**
- **`telegraf/telegraf-zcam.conf`** - Telegraf HTTP response 監控配置
- **`docker-compose-telegraf.yml`** - Telegraf Docker 服務配置

### 2. **Prometheus 配置**
- **`prometheus.yml`** - 更新 scrape 配置以收集 Telegraf metrics

### 3. **Grafana Dashboard**
- **`grafana/provisioning/dashboards/zcam/zcam-http-response-monitoring.json`** - 自定義 ZCAM HTTP 監控 dashboard

## 🔧 配置詳情

### **Telegraf HTTP Response 監控**

每台 ZCAM 設備監控 3 個關鍵 API 端點：

| 端點類型 | API 路徑 | 監控目的 |
|----------|----------|----------|
| RTMP Status | `/ctrl/rtmp?action=query&index=0` | 串流狀態監控 |
| Battery | `/ctrl/get?k=battery` | 電池電量監控 |
| Camera Mode | `/ctrl/mode` | 攝影機模式監控 |

### **收集的 Metrics**

Telegraf 為每個 API 端點收集以下 metrics：

1. **`http_response_response_time`** - API 回應時間 (秒)
2. **`http_response_http_response_code`** - HTTP 狀態碼
3. **`http_response_result_code`** - 結果代碼 (0=成功, 1=失敗)
4. **`http_response_content_length`** - 回應內容長度 (bytes)

### **Labels/Tags**

每個 metric 包含以下標籤：
- `device_name`: ZCAM 設備名稱 (如 zcam-aro11)
- `agent_name`: 對應的 Zabbix agent (如 aro11)
- `device_ip`: 設備 IP 位址
- `endpoint_type`: API 端點類型 (rtmp_status, battery, camera_mode)
- `environment`: 環境標籤 (production)
- `service`: 服務標籤 (zcam-monitoring)

## 📊 Dashboard 面板

### 1. **ZCAM API Response Time** (Time Series)
- 顯示所有設備和端點的 API 回應時間趨勢
- 單位: 秒 (s)
- 有助於識別效能問題

### 2. **ZCAM API Status Overview** (Table)
- 顯示所有設備的當前 HTTP 狀態碼
- 200 OK = 綠色，其他 = 紅色
- 快速識別離線或異常設備

### 3. **ZCAM API Health Status** (Stat)
- 顯示所有 API 端點的健康狀態
- SUCCESS (0) = 綠色，FAILED (1) = 紅色
- 整體系統健康狀況一目了然

### 4. **ZCAM API Response Content Length** (Time Series)
- 監控 API 回應內容長度變化
- 有助於檢測 API 回應異常

### 5. **ZCAM API Response Time Details** (Table)
- 詳細的回應時間表格視圖
- 按設備和端點分類顯示

## 🚀 部署步驟

### **Step 1: 啟動 Telegraf 服務**
```bash
cd /home/ella/kevin/telemetry
docker-compose -f docker-compose-telegraf.yml up -d
```

### **Step 2: 重新啟動 Prometheus**
```bash
docker restart kevin-telemetry-prometheus
```

### **Step 3: 重新啟動 Grafana**
```bash
docker restart kevin-telemetry-grafana
```

### **Step 4: 訪問 Dashboard**
1. 開啟 Grafana: http://100.64.0.113:3000
2. 導航到 "ZCAM HTTP Response Monitoring" dashboard
3. 查看所有 5 台設備的監控狀態

## 📈 當前監控狀態

根據最新測試結果：

### **所有設備 API 狀態** ✅
- **HTTP 狀態碼**: 全部 200 OK
- **結果代碼**: 全部 0 (成功)
- **回應時間**: 0.002-1.026 秒範圍

### **各設備詳細狀態**

| 設備 | IP | RTMP API | Battery API | Mode API |
|------|----|---------|-----------|---------| 
| zcam-aro11 | 192.168.88.10 | ✅ 200 OK | ✅ 200 OK | ✅ 200 OK |
| zcam-aro12 | 192.168.88.186 | ✅ 200 OK | ✅ 200 OK | ✅ 200 OK |
| zcam-aro21 | 192.168.88.12 | ✅ 200 OK | ✅ 200 OK | ✅ 200 OK |
| zcam-aro22 | 192.168.88.34 | ✅ 200 OK | ✅ 200 OK | ✅ 200 OK |
| zcam-asb11 | 192.168.88.14 | ✅ 200 OK | ✅ 200 OK | ✅ 200 OK |

## 🚨 告警建議

### **Prometheus 告警規則**
```yaml
groups:
  - name: zcam_http_response
    rules:
      - alert: ZCAMAPIDown
        expr: http_response_result_code{job="telegraf-zcam"} > 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "ZCAM API endpoint is down"
          description: "{{$labels.device_name}} {{$labels.endpoint_type}} API is not responding"
      
      - alert: ZCAMAPISlowResponse
        expr: http_response_response_time{job="telegraf-zcam"} > 5
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "ZCAM API slow response"
          description: "{{$labels.device_name}} {{$labels.endpoint_type}} API response time is {{$value}}s"
```

### **Grafana 告警**
- **HTTP 狀態碼 != 200**: 立即告警
- **回應時間 > 5 秒**: 警告
- **結果代碼 != 0**: 嚴重告警

## 🔧 故障排除

### **常見問題**

1. **Telegraf 容器無法啟動**
   ```bash
   docker logs kevin-telemetry-telegraf-zcam
   ```

2. **Prometheus 無法抓取 metrics**
   ```bash
   curl http://localhost:9273/metrics | grep http_response
   ```

3. **Grafana dashboard 沒有資料**
   - 檢查 Prometheus targets: http://100.64.0.113:9090/targets
   - 確認 telegraf-zcam job 狀態為 UP

4. **ZCAM 設備無回應**
   ```bash
   curl -I http://192.168.88.10/ctrl/rtmp?action=query&index=0
   ```

## 🎯 優勢與特色

### **相較於原有 Zabbix 監控的優勢**

1. **更好的視覺化**: Grafana 提供更豐富的圖表和儀表板
2. **實時監控**: 30 秒更新間隔，快速反應
3. **標準化 metrics**: 使用 Prometheus metrics 格式
4. **易於擴展**: 可輕鬆添加新的 ZCAM 設備
5. **HTTP 標準監控**: 基於業界標準的 HTTP response 監控方法

### **與 Zabbix 監控互補**

- **Telegraf/Grafana**: 專注於 HTTP API 可用性和效能
- **Zabbix**: 專注於業務邏輯監控 (電池電量、串流狀態等)
- **兩者結合**: 提供全面的 ZCAM 監控解決方案

## 📝 維護建議

### **定期檢查**
- 每週檢查 Telegraf 日誌
- 每月檢查 Prometheus metrics 保留政策
- 定期更新 dashboard 配置

### **擴展建議**
- 添加更多 ZCAM API 端點監控
- 整合 Slack/Email 告警
- 建立 SLA 監控面板
- 添加歷史趨勢分析

---

**建立日期**: 2025-09-19  
**最後更新**: 2025-09-19  
**狀態**: ✅ 生產環境運行中  
**參考**: [Grafana HTTP Response Monitoring Dashboard](https://grafana.com/grafana/dashboards/11777-http-response-monitoring/)
