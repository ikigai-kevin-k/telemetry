# 磁碟使用率監控設定指南

## 概述

本指南說明如何設定監控本地伺服器磁碟使用率（`/dev/mapper/ubuntu--vg-ubuntu--lv`）的 Prometheus metrics，並在 Grafana 中視覺化。

## 架構

```
Disk Usage Exporter (Python)
  ↓ (每 30 秒收集)
Prometheus (抓取 metrics)
  ↓ (儲存時間序列)
Grafana (視覺化)
```

## 組件說明

### 1. Disk Usage Exporter

**位置**: `scripts/disk-usage-exporter.py`

**功能**:
- 監控 `/dev/mapper/ubuntu--vg-ubuntu--lv` 檔案系統
- 使用 `df` 命令收集磁碟使用資訊
- 暴露 Prometheus metrics 在 port 9275

**暴露的 Metrics**:
- `disk_usage_percent{filesystem, mountpoint}` - 磁碟使用百分比
- `disk_total_bytes{filesystem, mountpoint}` - 總容量（bytes）
- `disk_used_bytes{filesystem, mountpoint}` - 已使用容量（bytes）
- `disk_available_bytes{filesystem, mountpoint}` - 可用容量（bytes）

### 2. Docker Compose 配置

**服務名稱**: `disk-usage-exporter`

**配置特點**:
- 使用 `host` network mode 以直接訪問主機檔案系統
- 使用 Python 3.11 Alpine 映像
- 自動安裝 `prometheus-client` 套件
- 自動重啟（`restart: unless-stopped`）

### 3. Prometheus 配置

**Job 名稱**: `disk-usage`

**抓取設定**:
- Target: `192.168.88.99:9275` (使用主機 IP，因為 disk-usage-exporter 使用 host network mode)
- 抓取間隔: 30 秒
- 超時時間: 10 秒

## 安裝步驟

### 步驟 1: 啟動 Disk Usage Exporter

```bash
# 啟動 exporter 服務（使用 docker-compose，帶連字號）
docker-compose up -d disk-usage-exporter

# 檢查容器狀態
docker ps | grep disk-usage-exporter

# 查看日誌
docker logs kevin-telemetry-disk-usage-exporter

# 重啟服務（如果需要）
docker-compose restart disk-usage-exporter
```

### 步驟 2: 驗證 Metrics 端點

```bash
# 測試 metrics 端點
curl http://localhost:9275/metrics

# 或使用測試腳本
./test_disk_usage_exporter.sh
```

### 步驟 3: 重新載入 Prometheus 配置

```bash
# 如果 Prometheus 已經在運行，重新載入配置
curl -X POST http://localhost:9090/-/reload

# 或重啟 Prometheus 容器
docker compose restart prometheus
```

### 步驟 4: 驗證 Prometheus 抓取

1. 開啟 Prometheus UI: http://localhost:9090
2. 前往 **Status > Targets**
3. 確認 `disk-usage` job 狀態為 **UP**

## 查詢範例

### Prometheus 查詢

```promql
# 查詢磁碟使用百分比
disk_usage_percent{filesystem="/dev/mapper/ubuntu--vg-ubuntu--lv"}

# 查詢已使用容量（GB）
disk_used_bytes{filesystem="/dev/mapper/ubuntu--vg-ubuntu--lv"} / 1024 / 1024 / 1024

# 查詢總容量（GB）
disk_total_bytes{filesystem="/dev/mapper/ubuntu--vg-ubuntu--lv"} / 1024 / 1024 / 1024

# 查詢可用容量（GB）
disk_available_bytes{filesystem="/dev/mapper/ubuntu--vg-ubuntu--lv"} / 1024 / 1024 / 1024
```

### Grafana 查詢

**Panel 1: 磁碟使用百分比（Gauge）**

```promql
disk_usage_percent{filesystem="/dev/mapper/ubuntu--vg-ubuntu--lv"}
```

**Panel 2: 磁碟使用趨勢（Time Series）**

```promql
disk_usage_percent{filesystem="/dev/mapper/ubuntu--vg-ubuntu--lv"}
```

**Panel 3: 已使用容量（Stat）**

```promql
disk_used_bytes{filesystem="/dev/mapper/ubuntu--vg-ubuntu--lv"} / 1024 / 1024 / 1024
```

**Panel 4: 可用容量（Stat）**

```promql
disk_available_bytes{filesystem="/dev/mapper/ubuntu--vg-ubuntu--lv"} / 1024 / 1024 / 1024
```

## Grafana Dashboard 設定建議

### 建立 Dashboard

1. 前往 Grafana: http://localhost:3000
2. 建立新的 Dashboard
3. 新增以下 Panels:

#### Panel 1: 磁碟使用百分比（Gauge）
- **Visualization**: Gauge
- **Query**: `disk_usage_percent{filesystem="/dev/mapper/ubuntu--vg-ubuntu--lv"}`
- **Unit**: Percent (0-100)
- **Thresholds**: 
  - Green: 0-70
  - Yellow: 70-85
  - Red: 85-100

#### Panel 2: 磁碟使用趨勢（Time Series）
- **Visualization**: Time series
- **Query**: `disk_usage_percent{filesystem="/dev/mapper/ubuntu--vg-ubuntu--lv"}`
- **Unit**: Percent (0-100)
- **Legend**: `{{filesystem}} - {{mountpoint}}`

#### Panel 3: 容量資訊（Stat）
- **Visualization**: Stat
- **Queries**:
  - Total: `disk_total_bytes{filesystem="/dev/mapper/ubuntu--vg-ubuntu--lv"} / 1024 / 1024 / 1024`
  - Used: `disk_used_bytes{filesystem="/dev/mapper/ubuntu--vg-ubuntu--lv"} / 1024 / 1024 / 1024`
  - Available: `disk_available_bytes{filesystem="/dev/mapper/ubuntu--vg-ubuntu--lv"} / 1024 / 1024 / 1024`
- **Unit**: GB

## 故障排查

### 問題 1: 容器無法啟動

**檢查**:
```bash
# 查看容器日誌
docker logs kevin-telemetry-disk-usage-exporter

# 檢查腳本權限
ls -l scripts/disk-usage-exporter.py
```

**解決方案**:
- 確認腳本有執行權限: `chmod +x scripts/disk-usage-exporter.py`
- 確認 Python 映像可以正常運行

### 問題 2: Metrics 端點無法訪問

**檢查**:
```bash
# 測試端點
curl http://localhost:9275/metrics

# 檢查容器網路
docker inspect kevin-telemetry-disk-usage-exporter | grep NetworkMode
```

**解決方案**:
- 確認容器使用 `host` network mode
- 確認 port 9275 沒有被其他服務佔用

### 問題 3: Prometheus 無法抓取 Metrics

**檢查**:
```bash
# 檢查 Prometheus targets
curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.job=="disk-usage")'

# 檢查 Prometheus 配置
docker exec kevin-telemetry-prometheus cat /etc/prometheus/prometheus.yml | grep -A 5 disk-usage
```

**解決方案**:
- 確認 Prometheus 配置已更新
- 重新載入 Prometheus 配置: `curl -X POST http://localhost:9090/-/reload`
- 檢查 Prometheus 日誌: `docker logs kevin-telemetry-prometheus`

### 問題 4: 無法讀取檔案系統資訊

**檢查**:
```bash
# 在容器內測試 df 命令
docker exec kevin-telemetry-disk-usage-exporter df -k /dev/mapper/ubuntu--vg-ubuntu--lv
```

**解決方案**:
- 確認容器使用 `host` network mode
- 確認主機檔案系統可訪問

## 監控告警建議

### Alert 規則範例

在 `prometheus.yml` 或獨立的 alert rules 檔案中新增：

```yaml
groups:
  - name: disk_usage_alerts
    rules:
      - alert: HighDiskUsage
        expr: disk_usage_percent{filesystem="/dev/mapper/ubuntu--vg-ubuntu--lv"} > 85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High disk usage detected"
          description: "Disk usage is {{ $value }}% on {{ $labels.filesystem }}"
      
      - alert: CriticalDiskUsage
        expr: disk_usage_percent{filesystem="/dev/mapper/ubuntu--vg-ubuntu--lv"} > 90
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Critical disk usage detected"
          description: "Disk usage is {{ $value }}% on {{ $labels.filesystem }}"
```

## 相關檔案

- `scripts/disk-usage-exporter.py` - Exporter 腳本
- `docker-compose.yml` - Docker Compose 配置
- `prometheus.yml` - Prometheus 配置
- `test_disk_usage_exporter.sh` - 測試腳本

## 更新記錄

- **2025-11-07**: 初始版本，支援監控 `/dev/mapper/ubuntu--vg-ubuntu--lv` 磁碟使用率

