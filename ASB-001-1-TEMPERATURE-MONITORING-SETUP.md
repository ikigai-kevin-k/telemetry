# ASB-001-1 溫度監控設定完成報告

## 概述
已成功為本機 `ASB-001-1` agent 設定溫度監控系統，完全仿造 `agent-temperature` 分支中其他 agent 的設定方式。

## 已完成的設定

### 1. 溫度監控腳本
- **文件**: `push_temperature_to_pushgateway_asb001.sh`
- **功能**: 讀取系統溫度並推送到 Prometheus Pushgateway
- **實例標籤**: `GC-ASB-001-1-agent`
- **指標名稱**: `system_temperature_celsius`
- **推送間隔**: 10 秒
- **Pushgateway URL**: `http://100.64.0.113:9091`

### 2. 啟動腳本
- **文件**: `start-temperature-exporter-asb001.sh`
- **功能**: 在背景啟動溫度監控服務
- **PID 文件**: `/tmp/temperature-exporter-asb001.pid`
- **日誌文件**: 
  - `/tmp/temperature-exporter-asb001.out`
  - `/tmp/temperature-exporter-asb001.err`

### 3. 服務整合
- **Pushgateway**: `http://100.64.0.113:9091` - 接收溫度數據
- **Prometheus**: `http://localhost:9090` - 從 Pushgateway 抓取數據
- **Grafana**: `http://localhost:3000` - 使用 Prometheus 作為數據源

## 使用方式

### 啟動溫度監控
```bash
cd /home/rnd/telemetry
bash start-temperature-exporter-asb001.sh
```

### 停止溫度監控
```bash
kill $(cat /tmp/temperature-exporter-asb001.pid)
```

### 檢查服務狀態
```bash
ps -p $(cat /tmp/temperature-exporter-asb001.pid)
```

### 查看日誌
```bash
tail -f /tmp/temperature-exporter-asb001.out
tail -f /tmp/temperature-exporter-asb001.err
```

## Grafana 查詢
在 Grafana 中可以使用以下 PromQL 查詢溫度數據：

```promql
system_temperature_celsius{instance="GC-ASB-001-1-agent"}
```

## 與其他 agent 的差異
- **實例標籤**: `GC-ASB-001-1-agent` (獨特標識)
- **PID 文件**: `/tmp/temperature-exporter-asb001.pid`
- **日誌文件**: `/tmp/temperature-exporter-asb001.out/err`
- **臨時檔案**: `/tmp/metrics-asb001.txt`

## 技術細節
- 使用 `sensors -j` 命令讀取系統溫度
- 使用 `jq` 解析 JSON 格式的溫度數據
- 使用 `curl` 推送 metrics 到 Pushgateway
- 支援多個溫度感測器，優先使用 `temp1_input` 值
- 溫度值格式化為 3 位小數
- 使用臨時檔案避免 shell 轉義問題

## 注意事項
- 溫度數據每 10 秒更新一次
- 服務會在系統重啟後停止，需要手動重新啟動
- 確保 lm-sensors 和 jq 工具已安裝
- Pushgateway 和 Prometheus 服務需要保持運行
- 與其他 agent 使用相同的 Pushgateway 服務器，但使用不同的實例標籤進行區分

## 驗證步驟
1. 啟動溫度監控服務
2. 檢查 PID 文件是否存在
3. 查看日誌確認無錯誤
4. 在 Pushgateway 中驗證 metrics 接收
5. 在 Prometheus 中查詢溫度數據
6. 在 Grafana 中建立溫度監控儀表板

## 完成時間
2025-10-29 (基於 agent-temperature 分支的最近四次 commits)
