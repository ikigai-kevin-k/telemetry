# ARO-001-1 溫度監控設定完成

## 概述
已成功為本機 aro-001-1 設定溫度監控系統，仿造 agent-temperature 分支中 aro-002-1 agent 的設定。

## 已完成的設定

### 1. 溫度監控腳本
- **文件**: `push_temperature_to_pushgateway_aro001.sh`
- **功能**: 讀取系統溫度並推送到 Prometheus Pushgateway
- **實例標籤**: `GC-ARO-001-1-agent`
- **指標名稱**: `system_temperature_celsius`
- **推送間隔**: 10 秒

### 2. 啟動腳本
- **文件**: `start-temperature-exporter-aro001.sh`
- **功能**: 在背景啟動溫度監控服務
- **PID 文件**: `/tmp/temperature-exporter-aro001.pid`
- **日誌文件**: 
  - `/tmp/temperature-exporter-aro001.out`
  - `/tmp/temperature-exporter-aro001.err`

### 3. 服務整合
- **Pushgateway**: `http://localhost:9091` - 接收溫度數據
- **Prometheus**: `http://localhost:9090` - 從 Pushgateway 抓取數據
- **Grafana**: `http://localhost:3000` - 使用 Prometheus 作為數據源

## 驗證結果
✅ 溫度監控服務正常運行 (PID: 2026361)
✅ Pushgateway 成功接收溫度數據
✅ Prometheus 成功查詢到溫度 metrics
✅ Grafana 服務正常運行並配置了 Prometheus 數據源

## 使用方式

### 啟動溫度監控
```bash
cd /home/rnd/telemetry
bash start-temperature-exporter-aro001.sh
```

### 停止溫度監控
```bash
kill $(cat /tmp/temperature-exporter-aro001.pid)
```

### 檢查服務狀態
```bash
ps -p $(cat /tmp/temperature-exporter-aro001.pid)
```

### 查看日誌
```bash
tail -f /tmp/temperature-exporter-aro001.out
tail -f /tmp/temperature-exporter-aro001.err
```

## Grafana 查詢
在 Grafana 中可以使用以下 PromQL 查詢溫度數據：

```promql
system_temperature_celsius{instance="GC-ARO-001-1-agent"}
```

## 注意事項
- 溫度數據每 10 秒更新一次
- 服務會在系統重啟後停止，需要手動重新啟動
- 確保 lm-sensors 和 jq 工具已安裝
- Pushgateway 和 Prometheus 服務需要保持運行
