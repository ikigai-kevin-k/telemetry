# Fix: ARO-002-1/ARO-002-2 Network Traffic Data Too Small - Agent-side Solutions

## 背景與問題描述

**問題主機：** `GC-ARO-002-1-agent` (ARO21) 和 `GC-ARO-002-2-agent` (ARO22)  
**影響範圍：** Grafana dashboard 中 ARO21 和 ARO22 的網絡流量數據異常小（約 3-4 Kbps），而其他 agents (ARO11, ARO12, ASB11) 正常顯示 6-7 Mbps

### 問題狀態

1. ✅ **Server-side 配置已完成**：
   - Zabbix items 已創建並啟用
   - Units 已更新為 "bps"
   - Grafana dashboard 單位 override 已設置

2. ❌ **實際數據值異常小**：
   - ARO21: 約 3,000-4,000 bps (3-4 Kbps)
   - ARO22: 約 3,000-4,000 bps (3-4 Kbps)
   - 對比：ARO12: 約 6,900,000 bps (6.9 Mbps)

3. ✅ **原始數據可查詢**：
   - Zabbix server 可以通過 `zabbix_get` 查詢到原始累計值
   - 但 30 秒內的變化量很小（約 14,000 bytes）

### 關鍵觀察

- Zabbix server 可以連接到 agents 並查詢數據
- 原始累計值在增長，但增長速度很慢
- 30 秒內只增加了約 14,000 bytes，對應約 3.8 Kbps
- 其他 agents (ARO12) 在相同時間內增加了約 26,000,000 bytes，對應約 6.9 Mbps

## 影響範圍與根因推測

### 可能原因（依優先順序）

1. **網絡介面實際流量很小**
   - ARO21/ARO22 的實際網絡流量就是這麼小
   - 可能是網絡配置問題或流量確實很低

2. **Zabbix Agent 讀取錯誤的介面**
   - Agent 可能讀取了錯誤的網絡介面
   - 需要確認實際使用的網絡介面名稱

3. **網絡介面狀態異常**
   - 網絡介面可能處於異常狀態
   - 需要檢查介面的 up/down 狀態和錯誤統計

4. **Zabbix Agent 配置問題**
   - Agent 配置可能有問題
   - 需要檢查 agent 配置和 UserParameter

## Agent-side 修改建議

### 方案 A：檢查並修正網絡介面配置（推薦優先嘗試）

**步驟 1：確認實際使用的網絡介面**

在 agent-side 執行：

```bash
# 檢查所有網絡介面
ip -o link show

# 檢查網絡流量統計
cat /sys/class/net/eth0/statistics/rx_bytes
cat /sys/class/net/eth0/statistics/tx_bytes

# 檢查是否有其他活躍的網絡介面
ip -s link show

# 檢查網絡介面狀態
ip link show eth0
```

**步驟 2：確認 Zabbix Agent 讀取的介面**

檢查 Zabbix Agent 配置：

```bash
# 在 agent container 中
docker exec <zabbix-agent-container> cat /etc/zabbix/zabbix_agent2.conf | grep -i network
docker exec <zabbix-agent-container> zabbix_agent2 -t net.if.in[eth0]
```

**步驟 3：如果介面名稱不正確，更新配置**

如果實際使用的介面不是 `eth0`，需要：
1. 更新 Zabbix Agent 配置中的介面名稱
2. 或更新 Zabbix server 中的 item key

### 方案 B：使用自定義 UserParameter 直接讀取系統文件

**優點：**
- 不依賴 Zabbix 內建的 `net.if.in[*]` key
- 可以直接讀取 `/sys/class/net/eth0/statistics/rx_bytes`
- 更容易 debug 和驗證

**實施步驟：**

1. **在 agent-side 的 `agent2-GC-ARO-002-1-agent.conf` 中添加**：

```conf
# Custom network interface monitoring
UserParameter=custom.net.if.in.bytes[*],cat /sys/class/net/$1/statistics/rx_bytes
UserParameter=custom.net.if.out.bytes[*],cat /sys/class/net/$1/statistics/tx_bytes
```

2. **在 Zabbix server 中創建新的 items**：
   - Key: `custom.net.if.in.bytes[eth0]`
   - Preprocessing: Change per second → Multiply by 8
   - Units: `bps`

3. **更新 Grafana dashboard 查詢**：
   - 使用新的 item key: `custom.net.if.in.bytes[eth0]`

### 方案 C：使用 Prometheus Node Exporter（更輕量級替代方案）

**優點：**
- 更輕量級，資源占用更少
- 更容易開發和 debug
- 直接暴露 Prometheus metrics，無需 Zabbix 中間層
- 標準化的 metrics 格式

**實施步驟：**

1. **在 agent-side 部署 Node Exporter**：

```yaml
# docker-compose-GC-ARO-002-1-agent.yml
services:
  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter-aro21
    command:
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
      - '--path.rootfs=/rootfs'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    ports:
      - "9100:9100"
    restart: unless-stopped
```

2. **在 server-side Prometheus 配置中添加 scraping job**：

```yaml
# prometheus.yml
  - job_name: 'node-exporter-aro21'
    static_configs:
      - targets: ['100.64.0.143:9100']  # GC-ARO-002-1-agent
    metrics_path: '/metrics'
    scrape_interval: 30s
    scrape_timeout: 10s

  - job_name: 'node-exporter-aro22'
    static_configs:
      - targets: ['100.64.0.144:9100']  # GC-ARO-002-2-agent
    metrics_path: '/metrics'
    scrape_interval: 30s
    scrape_timeout: 10s
```

3. **在 Grafana 中使用 Prometheus 查詢**：

```promql
# ARO21
rate(node_network_receive_bytes_total{device="eth0",instance="100.64.0.143:9100"}[30s]) * 8

# ARO22
rate(node_network_receive_bytes_total{device="eth0",instance="100.64.0.144:9100"}[30s]) * 8
```

**Metrics 說明：**
- `node_network_receive_bytes_total`: 接收的總字節數（累計值）
- `rate()`: 計算每秒變化率
- `* 8`: 轉換為 bits per second

### 方案 D：使用自定義 Python Exporter（最靈活）

**優點：**
- 完全可控，可以自定義 metrics
- 容易添加額外的監控指標
- 可以直接讀取系統文件或使用其他工具
- 易於 debug 和開發

**實施步驟：**

1. **創建 Python exporter 腳本**：

```python
#!/usr/bin/env python3
"""
Network Interface Exporter for ARO-002-1/ARO-002-2
Exports network interface statistics as Prometheus metrics
"""

import time
import os
from prometheus_client import start_http_server, Gauge

# Prometheus metrics
network_rx_bytes = Gauge('network_interface_rx_bytes_total', 
                         'Total bytes received on network interface', 
                         ['interface', 'instance'])
network_tx_bytes = Gauge('network_interface_tx_bytes_total', 
                         'Total bytes transmitted on network interface', 
                         ['interface', 'instance'])

def read_interface_stats(interface):
    """Read network interface statistics from /sys/class/net"""
    rx_path = f'/sys/class/net/{interface}/statistics/rx_bytes'
    tx_path = f'/sys/class/net/{interface}/statistics/tx_bytes'
    
    try:
        with open(rx_path, 'r') as f:
            rx_bytes = int(f.read().strip())
        with open(tx_path, 'r') as f:
            tx_bytes = int(f.read().strip())
        return rx_bytes, tx_bytes
    except Exception as e:
        print(f"Error reading {interface}: {e}")
        return None, None

def update_metrics():
    """Update Prometheus metrics"""
    interface = os.getenv('NETWORK_INTERFACE', 'eth0')
    instance = os.getenv('INSTANCE_NAME', 'aro21')
    
    rx_bytes, tx_bytes = read_interface_stats(interface)
    if rx_bytes is not None:
        network_rx_bytes.labels(interface=interface, instance=instance).set(rx_bytes)
        network_tx_bytes.labels(interface=interface, instance=instance).set(tx_bytes)
        print(f"Updated metrics: {interface} - RX: {rx_bytes}, TX: {tx_bytes}")

if __name__ == '__main__':
    # Start HTTP server on port 9276
    start_http_server(9276)
    print("Network interface exporter started on port 9276")
    
    # Update metrics every 30 seconds
    while True:
        update_metrics()
        time.sleep(30)
```

2. **在 agent-side 部署 exporter**：

```yaml
# docker-compose-GC-ARO-002-1-agent.yml
services:
  network-exporter:
    image: python:3.11-alpine
    container_name: network-exporter-aro21
    restart: unless-stopped
    working_dir: /app
    command: sh -c "pip install prometheus-client && python network-exporter.py"
    volumes:
      - ./scripts/network-exporter.py:/app/network-exporter.py:ro
      - /sys:/sys:ro
    ports:
      - "9276:9276"
    environment:
      - NETWORK_INTERFACE=eth0
      - INSTANCE_NAME=aro21
    network_mode: "host"  # 需要訪問 host 的 /sys
```

3. **在 server-side Prometheus 配置中添加**：

```yaml
  - job_name: 'network-exporter-aro21'
    static_configs:
      - targets: ['100.64.0.143:9276']
    metrics_path: '/metrics'
    scrape_interval: 30s

  - job_name: 'network-exporter-aro22'
    static_configs:
      - targets: ['100.64.0.144:9276']
    metrics_path: '/metrics'
    scrape_interval: 30s
```

4. **在 Grafana 中使用 Prometheus 查詢**：

```promql
# ARO21
rate(network_interface_rx_bytes_total{interface="eth0",instance="aro21"}[30s]) * 8

# ARO22
rate(network_interface_rx_bytes_total{interface="eth0",instance="aro22"}[30s]) * 8
```

## 替代方案比較

| 方案 | 優點 | 缺點 | 推薦度 |
|------|------|------|--------|
| **方案 A: 檢查 Zabbix 配置** | 無需額外部署，使用現有架構 | 依賴 Zabbix，debug 較困難 | ⭐⭐⭐ |
| **方案 B: 自定義 UserParameter** | 簡單，直接讀取系統文件 | 仍依賴 Zabbix | ⭐⭐⭐ |
| **方案 C: Node Exporter** | 標準化，輕量級，易於 debug | 需要額外部署 | ⭐⭐⭐⭐ |
| **方案 D: 自定義 Python Exporter** | 最靈活，完全可控 | 需要開發和維護 | ⭐⭐⭐⭐⭐ |

## 推薦實施順序

1. **首先嘗試方案 A**：檢查網絡介面配置，確認問題根源
2. **如果方案 A 無法解決，嘗試方案 B**：使用自定義 UserParameter
3. **長期方案：考慮方案 C 或 D**：使用更輕量級的 Prometheus-based 方案

## 驗證步驟

### 方案 A/B 驗證

```bash
# 在 agent-side
# 1. 檢查實際網絡介面
ip -o link show

# 2. 檢查流量統計
watch -n 1 'cat /sys/class/net/eth0/statistics/rx_bytes'

# 3. 測試 Zabbix agent
docker exec <zabbix-agent> zabbix_agent2 -t net.if.in[eth0]
docker exec <zabbix-agent> zabbix_agent2 -t custom.net.if.in.bytes[eth0]
```

### 方案 C/D 驗證

```bash
# 在 agent-side
# 1. 檢查 exporter 是否運行
curl http://localhost:9100/metrics | grep network
# 或
curl http://localhost:9276/metrics | grep network

# 2. 在 server-side 檢查 Prometheus
curl 'http://localhost:9090/api/v1/query?query=up{job="node-exporter-aro21"}'
```

## 風險與回滾方案

### 風險

- 方案 C/D 需要額外部署和維護
- 可能需要修改 Grafana dashboard 查詢
- 需要確保網絡連接正常

### 回滾方案

1. 如果使用方案 C/D，可以保留 Zabbix 配置作為備份
2. 如果出現問題，可以切換回 Zabbix 查詢
3. 可以同時運行兩種方案，逐步遷移

## 預期結果

- ✅ ARO21 和 ARO22 的網絡流量數據正常顯示（6-7 Mbps 範圍）
- ✅ 數據持續更新，不再出現異常小的數值
- ✅ 單位一致，與其他 agents 相同

## 相關文件

- `/home/ella/kevin/telemetry/zabbix/agent2-GC-ARO-002-1-agent.conf` - Agent 配置
- `/home/ella/kevin/telemetry/zabbix/agent2-GC-ARO-002-2-agent.conf` - Agent 配置
- `/home/ella/kevin/telemetry/zabbix/create_eth0_interface_items.sh` - Server-side 創建 items 的腳本
- `/home/ella/kevin/telemetry/grafana/provisioning/dashboards/general/overview.json` - Grafana Dashboard 配置

## 修復日期

2025-11-28

