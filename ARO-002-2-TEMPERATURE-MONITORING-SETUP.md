# ARO-002-2 溫度監控設定完成報告

## 概述
已成功為本機 `ARO-002-2` agent 設定溫度監控系統，完全仿造其他 agent（如 ARO-001-1、ARO-001-2、ASB-001-1）的設定方式。

## 問題診斷
- **問題**: Grafana 中 ARO-002-2 的 AIPC 系統溫度資料顯示為一條水平線（固定 40°C），沒有變化
- **原因**: 
  1. 缺少 ARO-002-2 專用的溫度推送腳本
  2. 沒有正在運行的溫度監控程序
  3. Pushgateway 中存在舊的固定值資料（40°C）

## 已完成的設定

### 1. 溫度監控腳本
- **文件**: `push_temperature_to_pushgateway_aro002_2.sh`
- **功能**: 讀取系統溫度並推送到 Prometheus Pushgateway
- **實例標籤**: `GC-ARO-002-2-agent`
- **指標名稱**: `system_temperature_celsius`
- **推送間隔**: 10 秒
- **Pushgateway URL**: `http://100.64.0.113:9091`

### 2. 啟動腳本
- **文件**: `start-temperature-exporter-aro002-2.sh`
- **功能**: 在背景啟動溫度監控服務
- **PID 文件**: `/tmp/temperature-exporter-aro002-2.pid`
- **日誌文件**: 
  - `/tmp/temperature-exporter-aro002-2.out`
  - `/tmp/temperature-exporter-aro002-2.err`

### 3. 服務整合
- **Pushgateway**: `http://100.64.0.113:9091` - 接收溫度數據
- **Prometheus**: 從 Pushgateway 抓取數據
- **Grafana**: 使用 Prometheus 作為數據源顯示溫度圖表

## 修復步驟
1. 建立 `push_temperature_to_pushgateway_aro002_2.sh` 腳本
2. 建立 `start-temperature-exporter-aro002-2.sh` 啟動腳本
3. 刪除 Pushgateway 中的舊固定值資料
4. 修正推送 URL 格式（使用 `/instance/${INSTANCE_LABEL}` 路徑）
5. 啟動溫度監控服務

## 驗證結果
✅ 溫度監控服務正常運行 (PID: 3895371)
✅ Pushgateway 成功接收溫度數據
✅ 溫度數據正常變化（約 39.75°C，不再固定為 40°C）
✅ 溫度值每 10 秒更新一次

## 使用方式

### 啟動溫度監控
```bash
cd /home/rnd/telemetry
bash start-temperature-exporter-aro002-2.sh
```

### 停止溫度監控
```bash
kill $(cat /tmp/temperature-exporter-aro002-2.pid)
```

### 檢查服務狀態
```bash
ps -p $(cat /tmp/temperature-exporter-aro002-2.pid)
```

### 查看日誌
```bash
tail -f /tmp/temperature-exporter-aro002-2.out
tail -f /tmp/temperature-exporter-aro002-2.err
```

## Grafana 查詢
在 Grafana 中可以使用以下 PromQL 查詢溫度數據：

```promql
system_temperature_celsius{instance="GC-ARO-002-2-agent"}
```

## 與其他 agent 的差異
- **實例標籤**: `GC-ARO-002-2-agent` (獨特標識)
- **PID 文件**: `/tmp/temperature-exporter-aro002-2.pid`
- **日誌文件**: `/tmp/temperature-exporter-aro002-2.out/err`
- **臨時檔案**: `/tmp/metrics-aro002-2.txt`

## 技術細節
- 使用 `sensors -j` 命令讀取系統溫度
- 使用 `jq` 解析 JSON 格式的溫度數據
- 使用 `curl` 推送 metrics 到 Pushgateway
- 推送 URL 格式: `${PUSHGATEWAY_URL}/metrics/job/${JOB_NAME}/instance/${INSTANCE_LABEL}`

## 注意事項
- 溫度數據每 10 秒更新一次
- 服務會在系統重啟後停止，需要手動重新啟動
- 確保 lm-sensors 和 jq 工具已安裝
- Pushgateway 和 Prometheus 服務需要保持運行

