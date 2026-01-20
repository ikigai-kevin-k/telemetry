# Grafana System Overview Dashboard - Metrics 資料流程分析

## 概述

本文檔詳細說明 Grafana System Overview Dashboard 中以下三個 panel 的 metrics 資料流程：
1. **AIPC - CPU Usage**
2. **AIPC Network Traffic - All Agents**
3. **AIPC - Temperature**

---

## 一、AIPC - CPU Usage

### Panel 配置
- **Panel ID**: 5
- **資料來源**: Zabbix Datasource (`zabbix-datasource`)
- **查詢項目**: `Linux: CPU utilization`
- **監控主機**: 
  - GC-ARO-001-1-agent (ARO11)
  - GC-aro12-agent (ARO12)
  - GC-ARO-002-1-agent (ARO21)
  - GC-ARO-002-2-agent (ARO22)
  - GC-ASB-001-1-agent (ASB11)

### 資料流程

```
┌─────────────────┐
│  AIPC Agent     │
│  (Host System)  │
└────────┬────────┘
         │
         │ 1. Zabbix Agent 執行 system_monitor.sh cpu_usage
         │    UserParameter: system.cpu.usage
         │
         ▼
┌─────────────────┐
│ Zabbix Agent    │
│ Container       │
│ Port: 10050     │
└────────┬────────┘
         │
         │ 2. Zabbix Server 主動抓取 (Active Check)
         │    或 Agent 主動推送 (Passive Check)
         │
         ▼
┌─────────────────┐
│ Zabbix Server   │
│ Container       │
│ Port: 10051     │
└────────┬────────┘
         │
         │ 3. 儲存到 Zabbix Database (MySQL)
         │
         ▼
┌─────────────────┐
│ Zabbix Database │
│ (MySQL)         │
│ Volume:         │
│ telemetry_      │
│ zabbix_db_data  │
└────────┬────────┘
         │
         │ 4. Grafana Zabbix Datasource Plugin
         │    透過 Zabbix API 查詢
         │    URL: http://localhost:8080/api_jsonrpc.php
         │
         ▼
┌─────────────────┐
│ Grafana         │
│ Dashboard       │
│ Panel:          │
│ AIPC - CPU      │
│ Usage           │
└─────────────────┘
```

### 詳細說明

#### 1. 資料收集層 (Agent Side)

**Zabbix Agent 配置** (`zabbix/agent2-*.conf`):
```conf
UserParameter=system.cpu.usage,/var/lib/zabbix/scripts/system_monitor.sh cpu_usage
```

**收集腳本** (`zabbix/scripts/system_monitor.sh`):
- 執行 `cpu_usage` 函數
- 從 `/proc/stat` 讀取 CPU 使用率
- 計算百分比並返回數值

#### 2. 資料傳輸層

**Zabbix Server 抓取方式**:
- **Active Check**: Zabbix Server 主動向 Agent 請求資料
- **Passive Check**: Agent 主動向 Server 推送資料
- 通訊協定: Zabbix Protocol (TCP Port 10050/10051)

#### 3. 資料儲存層

**Zabbix Database**:
- 資料庫: MySQL
- Volume: `telemetry_zabbix_db_data`
- 儲存位置: `/var/lib/docker/volumes/telemetry_zabbix_db_data/_data`
- 資料表: `history`, `trends` 等

#### 4. 資料展示層

**Grafana Zabbix Datasource**:
- Plugin: `alexanderzobnin-zabbix-datasource`
- 配置檔案: `grafana/provisioning/datasources/zabbix.yml`
- 查詢方式: 透過 Zabbix API (`api_jsonrpc.php`)
- 查詢模式: `Metrics` (Query Mode)

**Dashboard 查詢配置**:
```json
{
  "host": {"filter": "GC-ARO-001-1-agent"},
  "item": {"filter": "Linux: CPU utilization"},
  "queryType": "0",
  "resultFormat": "time_series"
}
```

---

## 二、AIPC Network Traffic - All Agents

### Panel 配置
- **Panel ID**: 12
- **資料來源**: Zabbix Datasource (`zabbix-datasource`)
- **查詢項目**: 
  - `Interface enp86s0: Bits received (Rate)` (ARO11)
  - `Interface enp86s0: Bits received` (ARO12)
  - `Interface eth0: Bits received` (ARO21, ARO22, ASB11)
- **監控主機**: 同上

### 資料流程

```
┌─────────────────┐
│  AIPC Agent     │
│  (Host System)  │
└────────┬────────┘
         │
         │ 1. Zabbix Agent 讀取網路介面統計
         │    - /sys/class/net/enp86s0/statistics/rx_bytes
         │    - /sys/class/net/eth0/statistics/rx_bytes
         │    或使用 net.if.in[*] 內建 key
         │
         ▼
┌─────────────────┐
│ Zabbix Agent    │
│ Container       │
│ Port: 10050     │
└────────┬────────┘
         │
         │ 2. Zabbix Server 抓取網路流量資料
         │
         ▼
┌─────────────────┐
│ Zabbix Server   │
│ Container       │
│ Port: 10051     │
└────────┬────────┘
         │
         │ 3. 儲存到 Zabbix Database
         │
         ▼
┌─────────────────┐
│ Zabbix Database │
│ (MySQL)         │
└────────┬────────┘
         │
         │ 4. Grafana Zabbix Datasource Plugin
         │
         ▼
┌─────────────────┐
│ Grafana         │
│ Dashboard       │
│ Panel:          │
│ AIPC Network    │
│ Traffic         │
└─────────────────┘
```

### 詳細說明

#### 1. 資料收集層

**網路介面監控**:
- Zabbix 使用內建的 `net.if.in[*]` 和 `net.if.out[*]` keys
- 或使用自定義 UserParameter（如 `custom.net.if.in[*]`）
- 讀取 `/sys/class/net/<interface>/statistics/rx_bytes` 和 `tx_bytes`

**不同介面處理**:
- **enp86s0**: 用於 ARO11, ARO12, ASB11
- **eth0**: 用於 ARO21, ARO22

#### 2. 資料轉換

**Rate 計算**:
- Zabbix 自動計算速率（每秒位元數）
- 使用 `Interface enp86s0: Bits received (Rate)` 項目
- 或使用 `rate()` 函數在 Grafana 中計算

#### 3. Dashboard 查詢配置

```json
{
  "host": {"filter": "GC-ARO-001-1-agent"},
  "item": {"filter": "Interface enp86s0: Bits received (Rate)"},
  "queryType": "0",
  "resultFormat": "time_series"
}
```

---

## 三、AIPC - Temperature

### Panel 配置
- **Panel ID**: 13
- **資料來源**: Prometheus Datasource (`PBFA97CFB590B2093`)
- **查詢 Metric**: `system_temperature_celsius{instance="GC-ARO-001-1-agent"}`
- **監控主機**: 同上

### 資料流程

```
┌─────────────────┐
│  AIPC Agent     │
│  (Host System)  │
└────────┬────────┘
         │
         │ 1. Zabbix Agent 執行 system_monitor.sh temperature
         │    UserParameter: system.temperature
         │    讀取 /sys/class/thermal/thermal_zone*/temp
         │
         ▼
┌─────────────────┐
│ Zabbix Agent    │
│ Container       │
│ Port: 10050     │
└────────┬────────┘
         │
         │ 2. Zabbix Server 抓取溫度資料
         │
         ▼
┌─────────────────┐
│ Zabbix Server   │
│ Container       │
│ Port: 10051     │
└────────┬────────┘
         │
         │ 3. Server-side 腳本收集溫度
         │    push_agent_temperature_to_pushgateway.sh
         │    每分鐘執行一次 (Cron: */1 * * * *)
         │
         ▼
┌─────────────────┐
│ Pushgateway     │
│ Container       │
│ Port: 9091      │
│ Job:            │
│ agent_temperature│
└────────┬────────┘
         │
         │ 4. Prometheus 抓取 Pushgateway metrics
         │    Job: pushgateway
         │    Scrape Interval: 15s
         │
         ▼
┌─────────────────┐
│ Prometheus      │
│ Container       │
│ Port: 9090      │
│ TSDB:           │
│ /prometheus     │
└────────┬────────┘
         │
         │ 5. Grafana Prometheus Datasource
         │    URL: http://localhost:9090
         │
         ▼
┌─────────────────┐
│ Grafana         │
│ Dashboard       │
│ Panel:          │
│ AIPC -          │
│ Temperature     │
└─────────────────┘
```

### 詳細說明

#### 1. 資料收集層 (Agent Side)

**Zabbix Agent 配置**:
```conf
UserParameter=system.temperature,/var/lib/zabbix/scripts/system_monitor.sh temperature
```

**收集腳本** (`zabbix/scripts/system_monitor.sh`):
```bash
get_temperature() {
    # 讀取 /sys/class/thermal/thermal_zone*/temp
    # 轉換為攝氏度（從毫度）
    # 回傳溫度數值
}
```

#### 2. 資料轉換層 (Server Side)

**轉換腳本** (`scripts/push_agent_temperature_to_pushgateway.sh`):
- 從 Zabbix Server 容器執行 `zabbix_get` 命令
- 查詢每個 Agent 的 `system.temperature` key
- 將資料轉換為 Prometheus metric 格式
- 推送到 Pushgateway

**推送格式**:
```prometheus
# HELP system_temperature_celsius Current system temperature in Celsius
# TYPE system_temperature_celsius gauge
system_temperature_celsius{instance="GC-ARO-001-1-agent"} 45.0
```

**推送 URL**:
```
POST http://localhost:9091/metrics/job/agent_temperature/instance/GC-ARO-001-1-agent
```

#### 3. 資料中繼層 (Pushgateway)

**Pushgateway 功能**:
- 接收來自短期任務或批處理作業的 metrics
- 提供 Prometheus 格式的 metrics 端點
- 資料不會自動過期，需要手動刪除或設定 TTL

**配置**:
- Container: `kevin-telemetry-pushgateway`
- Port: `9091`
- Metrics 端點: `http://pushgateway:9091/metrics`

#### 4. 資料抓取層 (Prometheus)

**Prometheus 配置** (`prometheus.yml`):
```yaml
scrape_configs:
  - job_name: 'pushgateway'
    honor_labels: true
    static_configs:
      - targets: ['pushgateway:9091']
    scrape_interval: 15s
```

**抓取流程**:
- Prometheus 每 15 秒抓取一次 Pushgateway
- `honor_labels: true` 保留 Pushgateway 的 labels
- 儲存到 Prometheus TSDB

#### 5. 資料儲存層

**Prometheus TSDB**:
- 儲存路徑: `/prometheus`
- Volume: `telemetry_prometheus_data`
- 保留時間: 200 小時（約 8.3 天）

#### 6. 資料展示層

**Grafana Prometheus Datasource**:
- 配置檔案: `grafana/provisioning/datasources/prometheus.yml`
- URL: `http://localhost:9090`
- 查詢語言: PromQL

**Dashboard 查詢配置**:
```json
{
  "expr": "system_temperature_celsius{instance=\"GC-ARO-001-1-agent\"}",
  "legendFormat": "ARO11",
  "range": true
}
```

---

## 四、資料來源對比

| 項目 | CPU Usage | Network Traffic | Temperature |
|-----|-----------|-----------------|-------------|
| **資料來源** | Zabbix | Zabbix | Prometheus |
| **收集方式** | Zabbix Agent | Zabbix Agent | Zabbix Agent → Pushgateway |
| **儲存位置** | Zabbix DB | Zabbix DB | Prometheus TSDB |
| **查詢方式** | Zabbix API | Zabbix API | Prometheus API |
| **資料格式** | Zabbix Item | Zabbix Item | Prometheus Metric |
| **更新頻率** | Zabbix 抓取間隔 | Zabbix 抓取間隔 | 每分鐘（Cron）→ 15秒（Prometheus） |

---

## 五、關鍵配置檔案

### 1. Zabbix Agent 配置
- **位置**: `zabbix/agent2-*.conf`
- **關鍵配置**:
  ```conf
  UserParameter=system.cpu.usage,/var/lib/zabbix/scripts/system_monitor.sh cpu_usage
  UserParameter=system.temperature,/var/lib/zabbix/scripts/system_monitor.sh temperature
  ```

### 2. Zabbix Server 配置
- **位置**: `docker-compose.yml`
- **Container**: `kevin-telemetry-zabbix-server`
- **Port**: `10051`

### 3. Prometheus 配置
- **位置**: `prometheus.yml`
- **關鍵配置**:
  ```yaml
  - job_name: 'pushgateway'
    honor_labels: true
    static_configs:
      - targets: ['pushgateway:9091']
    scrape_interval: 15s
  ```

### 4. Pushgateway 配置
- **位置**: `docker-compose.yml`
- **Container**: `kevin-telemetry-pushgateway`
- **Port**: `9091`

### 5. Grafana Datasource 配置

**Zabbix Datasource** (`grafana/provisioning/datasources/zabbix.yml`):
```yaml
- name: Zabbix-New
  type: alexanderzobnin-zabbix-datasource
  url: http://localhost:8080/api_jsonrpc.php
  uid: zabbix-datasource
```

**Prometheus Datasource** (`grafana/provisioning/datasources/prometheus.yml`):
```yaml
- name: Prometheus
  type: prometheus
  url: http://localhost:9090
  uid: PBFA97CFB590B2093
```

### 6. 溫度收集腳本
- **位置**: `scripts/push_agent_temperature_to_pushgateway.sh`
- **執行頻率**: 每分鐘（Cron: `*/1 * * * *`）
- **功能**: 從 Zabbix 收集溫度並推送到 Pushgateway

---

## 六、資料流程圖總結

### CPU Usage & Network Traffic (Zabbix 路徑)
```
Agent → Zabbix Agent → Zabbix Server → Zabbix DB → Grafana (Zabbix Plugin)
```

### Temperature (混合路徑)
```
Agent → Zabbix Agent → Zabbix Server → Script → Pushgateway → Prometheus → Grafana (Prometheus)
```

---

## 七、故障排查

### CPU Usage / Network Traffic 無資料
1. 檢查 Zabbix Agent 是否運行
2. 檢查 Zabbix Server 是否能連接到 Agent
3. 檢查 Zabbix Database 是否有資料
4. 檢查 Grafana Zabbix Datasource 配置
5. 檢查 Dashboard 查詢配置（host, item 名稱）

### Temperature 無資料
1. 檢查 Zabbix Agent 溫度收集是否正常
2. 檢查 `push_agent_temperature_to_pushgateway.sh` 是否執行
3. 檢查 Pushgateway 是否有 metrics
   ```bash
   curl http://localhost:9091/metrics | grep system_temperature_celsius
   ```
4. 檢查 Prometheus 是否抓取到 Pushgateway metrics
   ```bash
   curl http://localhost:9090/api/v1/query?query=system_temperature_celsius
   ```
5. 檢查 Grafana Prometheus Datasource 配置
6. 檢查 Dashboard 查詢語法

---

## 八、相關檔案位置

### 配置檔案
- Zabbix Agent: `zabbix/agent2-*.conf`
- Zabbix Server: `docker-compose.yml`
- Prometheus: `prometheus.yml`
- Pushgateway: `docker-compose.yml`
- Grafana Datasources: `grafana/provisioning/datasources/*.yml`
- Grafana Dashboard: `grafana/provisioning/dashboards/general/overview.json`

### 腳本檔案
- 系統監控: `zabbix/scripts/system_monitor.sh`
- 溫度推送: `scripts/push_agent_temperature_to_pushgateway.sh`

### 資料儲存
- Zabbix DB: `/var/lib/docker/volumes/telemetry_zabbix_db_data/_data`
- Prometheus TSDB: `/var/lib/docker/volumes/telemetry_prometheus_data/_data`

---

**文件生成時間**: 2025-11-07  
**最後更新**: 2025-11-07














