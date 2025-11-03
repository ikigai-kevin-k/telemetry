# eBPF Exporter for Prometheus

本專案實作了一個使用 eBPF 技術的系統監測工具，用於監測本機系統的 CPU 使用率、溫度以及網路速度等 metrics，並將這些資料暴露給 Prometheus。

## 功能特點

- **CPU 監測**: 監測每個 CPU 核心的使用率百分比
- **溫度監測**: 監測 CPU 溫度（攝氏度）
- **網路速度監測**: 監測每個網路介面的上傳/下載速度（bytes per second）
- **系統負載**: 監測系統 1 分鐘、5 分鐘、15 分鐘的負載平均值
- **Prometheus 整合**: 自動暴露 metrics 供 Prometheus 抓取

## 架構

```
eBPF Programs (C) → Python Exporter → Prometheus Metrics → Prometheus Server
```

## 系統需求

- Linux 核心 4.9+ (支援 eBPF)
- Docker 和 Docker Compose
- 特權模式（privileged mode）以執行 eBPF 程式

## 安裝與使用

### 1. 啟動服務

從專案根目錄執行：

```bash
docker compose up -d ebpf-exporter
```

### 2. 驗證服務運行

檢查容器狀態：

```bash
docker ps | grep ebpf-exporter
```

檢查 metrics endpoint：

```bash
curl http://localhost:9300/metrics
```

檢查健康狀態：

```bash
curl http://localhost:9300/health
```

### 3. Prometheus 配置

eBPF exporter 已自動添加到 `prometheus.yml` 配置中：

```yaml
- job_name: 'ebpf-exporter'
  static_configs:
    - targets: ['localhost:9300']
  metrics_path: '/metrics'
  scrape_interval: 15s
  scrape_timeout: 10s
```

## Metrics 說明

### CPU Metrics

- `ebpf_cpu_usage_percent{cpu="0"}`: CPU 核心使用率百分比
- `ebpf_system_load{type="1min"}`: 系統 1 分鐘負載平均值
- `ebpf_system_load{type="5min"}`: 系統 5 分鐘負載平均值
- `ebpf_system_load{type="15min"}`: 系統 15 分鐘負載平均值

### 溫度 Metrics

- `ebpf_cpu_temperature_celsius{core="core0"}`: CPU 核心溫度（攝氏度）

### 網路 Metrics

- `ebpf_network_bytes_sent{interface="eth0"}`: 網路介面發送總位元組數
- `ebpf_network_bytes_recv{interface="eth0"}`: 網路介面接收總位元組數
- `ebpf_network_speed_sent_bps{interface="eth0"}`: 網路介面發送速度（bytes per second）
- `ebpf_network_speed_recv_bps{interface="eth0"}`: 網路介面接收速度（bytes per second）

## 故障排除

### 容器無法啟動

1. 確認系統支援 eBPF：
```bash
uname -r  # 需要 4.9+
```

2. 確認有特權模式權限

3. 檢查 Docker 日誌：
```bash
docker logs kevin-telemetry-ebpf-exporter
```

### Metrics 沒有資料

1. 檢查 exporter 是否正常運行：
```bash
curl http://localhost:9300/metrics | grep ebpf
```

2. 檢查 Prometheus 目標狀態：
   - 訪問 http://localhost:9090/targets
   - 確認 `ebpf-exporter` job 狀態為 "UP"

3. 重啟服務：
```bash
docker compose restart ebpf-exporter
docker compose restart prometheus
```

### 溫度讀取失敗

某些系統可能無法讀取 CPU 溫度。Exporter 會嘗試多種方法：
1. psutil sensors_temperatures()
2. /sys/class/thermal/*/temp

如果都失敗，溫度 metrics 可能為空。

## 開發與自訂

### 修改收集間隔

編輯 `ebpf_exporter.py` 中的 `time.sleep(5)` 來調整收集間隔。

### 添加新的 eBPF 程式

1. 在 `ebpf-exporter/` 目錄創建新的 `.c` 檔案
2. 在 `ebpf_exporter.py` 中載入並使用新的程式

### 環境變數

- `EXPORTER_PORT`: Exporter 監聽端口（預設: 9300）

## 授權

本專案遵循與主專案相同的授權條款。

