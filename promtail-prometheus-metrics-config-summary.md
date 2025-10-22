# Promtail Prometheus Metrics 配置修改摘要報告

## 📋 修改概要

**修改時間**: 2025-10-22 10:25 (UTC+4)  
**目標**: 讓 Promtail 直接傳送 rx_bits metrics 到 Prometheus  
**完成度**: 配置已修改，但需要進一步測試  

---

## 🛠️ 執行的修改

### ✅ 修改 1: 創建新的 "prom" branch

**操作**: 從 "agent" branch 創建新的 "prom" branch
```bash
git checkout -b prom
```

### ✅ 修改 2: 配置 Promtail Metrics Pipeline

**檔案**: `/home/rnd/telemetry/promtail-config.yml`

**修改前**:
```yaml
pipeline_stages:
  - json:
      expressions:
        rx_bits: rx_bits
```

**修改後**:
```yaml
pipeline_stages:
  - json:
      expressions:
        timestamp: timestamp
        rx_bits: rx_bits
  - timestamp:
      source: timestamp
      format: "2006-01-02 15:04:05.000"
      location: "Asia/Taipei"
  - metrics:
      network_rx_bits_total:
        type: Counter
        description: "Total received bits on network interface"
        source: rx_bits
        config:
          action: inc
```

**理由**: 
- 添加時間戳解析以確保正確的時間戳
- 使用 `metrics` stage 將 `rx_bits` 轉換為 Prometheus Counter metrics
- 設定 metrics 名稱為 `network_rx_bits_total`
- 使用 `inc` action 來增加 counter 值

---

## 📊 修改後的完整配置

### Promtail 配置檔案
```yaml
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://100.64.0.113:3100/loki/api/v1/push
    batchwait: 5s
    batchsize: 10
    timeout: 30s

scrape_configs:
  - job_name: network_stats
    static_configs:
      - targets:
          - localhost
        labels:
          job: network_monitor
          instance: GC-aro11-agent
          interface: enp86s0
          __path__: /var/log/network_stats.log
    pipeline_stages:
      - json:
          expressions:
            timestamp: timestamp
            rx_bits: rx_bits
      - timestamp:
          source: timestamp
          format: "2006-01-02 15:04:05.000"
          location: "Asia/Taipei"
      - metrics:
          network_rx_bits_total:
            type: Counter
            description: "Total received bits on network interface"
            source: rx_bits
            config:
              action: inc
```

---

## 🎯 修改結果

### 資料格式變化
**修改前**: 只提取 rx_bits 欄位
```yaml
- json:
    expressions:
      rx_bits: rx_bits
```

**修改後**: 轉換為 Prometheus Counter metrics
```yaml
- metrics:
    network_rx_bits_total:
      type: Counter
      description: "Total received bits on network interface"
      source: rx_bits
      config:
        action: inc
```

### Prometheus Metrics 優勢
1. **Counter 類型**: 適合累積的網路流量資料
2. **標準化格式**: 符合 Prometheus metrics 標準
3. **Grafana 兼容**: 可以直接在 Grafana 中查詢和視覺化
4. **時間序列**: 適合繪製時間序列圖表

---

## 🔍 技術細節

### 修改的檔案
- `/home/rnd/telemetry/promtail-config.yml`

### 執行的命令
```bash
# 創建新 branch
git checkout -b prom

# 重新啟動 Promtail
docker compose -f docker-compose.agent.yml restart promtail

# 手動測試
echo '{"timestamp": "2025-10-22 10:25:30.000", "interface": "enp86s0", "rx_bytes": 2208000000000, "rx_packets": 2247000000, "tx_bytes": 1823000000000, "tx_packets": 1453000000, "rx_bits": 17664000000000, "tx_bits": 14584000000000}' >> logs/network_stats.log
```

### 配置變更對比
| 參數 | 修改前 | 修改後 | 變更 |
|------|--------|--------|------|
| Pipeline Stages | 1 個 | 3 個 | +200% |
| Metrics 類型 | 無 | Counter | 新增 |
| 時間戳解析 | 無 | 有 | 新增 |
| Metrics 名稱 | 無 | network_rx_bits_total | 新增 |

---

## 🎯 當前狀態

### ✅ 已完成的工作
1. **創建新 branch** - "prom" branch 已創建
2. **配置 Metrics Pipeline** - 添加了 metrics stage
3. **設定 Counter 類型** - 使用 Counter 來累積 rx_bits
4. **添加時間戳解析** - 確保正確的時間戳
5. **重新啟動 Promtail** - 應用新配置

### ⚠️ 待解決的問題
1. **時間戳錯誤** - 仍然有 "entry too far behind" 錯誤
2. **Metrics 發送** - 沒有看到成功的 metrics 發送記錄
3. **Prometheus 連線** - 需要確認 Prometheus 是否接收 metrics

### 🔍 診斷結果
從 Promtail 日誌中可以看到：
- ✅ 成功添加目標：`Adding target key="/var/log/network_stats.log:{instance=\"GC-aro11-agent\", interface=\"enp86s0\", job=\"network_monitor\"}"`
- ✅ 開始監控檔案：`tail routine: started path="/var/log/network_stats.log"`
- ❌ **時間戳錯誤**：`entry too far behind`
- ❌ **沒有 metrics 發送記錄**

---

## 🔧 建議解決方案

### 方案 1: 修正時間戳問題
```yaml
- timestamp:
    source: timestamp
    format: "2006-01-02 15:04:05.000"
    location: "Local"  # 使用 Local 而不是 Asia/Taipei
```

### 方案 2: 檢查 Prometheus 連線
```bash
# 檢查 Prometheus 是否運行
curl http://100.64.0.113:9090/api/v1/query?query=up
```

### 方案 3: 使用不同的 Metrics 配置
```yaml
- metrics:
    network_rx_bits_total:
      type: Gauge  # 使用 Gauge 而不是 Counter
      description: "Current received bits on network interface"
      source: rx_bits
```

---

## 📊 技術支援資訊

- **Promtail 版本**: 3.5.5 (latest)
- **配置檔案**: `/home/rnd/telemetry/promtail-config.yml`
- **容器名稱**: `kevin-telemetry-promtail-agent`
- **Loki 服務器**: http://100.64.0.113:3100
- **Prometheus 服務器**: http://100.64.0.113:9090 (假設)
- **Log 檔案**: `/home/rnd/telemetry/logs/network_stats.log`
- **Branch**: prom

---

## 🎯 下一步行動

### 立即行動
1. **修正時間戳問題** - 調整時間戳配置
2. **檢查 Prometheus 連線** - 確認 Prometheus 服務器狀態
3. **測試 Metrics 發送** - 手動觸發新的 log 條目

### 持續監控
1. **檢查 Promtail 日誌** - 尋找 metrics 發送記錄
2. **檢查 Prometheus** - 確認 metrics 是否到達
3. **檢查 Grafana** - 確認可以從 Prometheus datasource 查詢 metrics

---

**修改完成時間**: 2025-10-22 10:25:00 AM +04  
**修改狀態**: 配置已修改，待解決時間戳問題  
**下一步**: 修正時間戳配置並測試 Prometheus 連線
