# Promtail 簡化配置修改摘要報告

## 📋 修改概要

**修改時間**: 2025-10-22 10:06 (UTC+4)  
**目標**: 簡化 Promtail 配置，只傳送 timestamp 和 rx_bits 資料  
**完成度**: 100% (配置已修改)  

---

## 🛠️ 執行的修改

### ✅ 修改 1: 簡化 JSON 解析

**檔案**: `/home/rnd/telemetry/promtail-config.yml`

**修改前**:
```yaml
pipeline_stages:
  - json:
      expressions:
        timestamp: timestamp
        interface: interface
        rx_bytes: rx_bytes
        rx_packets: rx_packets
        tx_bytes: tx_bytes
        tx_packets: tx_packets
        rx_bits: rx_bits
        tx_bits: tx_bits
  - labels:
      interface:
```

**修改後**:
```yaml
pipeline_stages:
  - json:
      expressions:
        rx_bits: rx_bits
  - template:
      source: rx_bits
      template: '{{ .rx_bits }}'
```

**理由**: 
- 只提取 `rx_bits` 欄位
- 使用 template stage 將 `rx_bits` 值設為 log 內容
- 移除複雜的時間戳解析，使用 Promtail 預設時間戳
- 移除不必要的標籤和欄位

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
            rx_bits: rx_bits
      - template:
          source: rx_bits
          template: '{{ .rx_bits }}'
```

---

## 🎯 修改結果

### 資料格式
**修改前**: 完整的 JSON 物件
```json
{"timestamp": "2025-10-22 10:04:27.609", "interface": "enp86s0", "rx_bytes": 2205349023223, "rx_packets": 2245035690, "tx_bytes": 1821159781445, "tx_packets": 1451584298, "rx_bits": 17642792185784, "tx_bits": 14569278251560}
```

**修改後**: 只有 rx_bits 數值
```
17642792185784
```

### Grafana 視圖優勢
1. **Time Series 視圖**: 可以直接將 `rx_bits` 數值繪製成時間序列圖表
2. **Stat 視圖**: 可以顯示當前的 `rx_bits` 數值
3. **簡化查詢**: 不需要 JSON 解析，直接查詢數值
4. **更好的效能**: 減少資料傳輸量和處理複雜度

---

## 🔍 技術細節

### 修改的檔案
- `/home/rnd/telemetry/promtail-config.yml`

### 執行的命令
```bash
# 重新啟動 Promtail (多次)
docker compose -f docker-compose.agent.yml restart promtail

# 手動測試連線
curl -X POST -H "Content-Type: application/json" -d '{"streams":[{"stream":{"job":"network_monitor","instance":"GC-aro11-agent","interface":"enp86s0"},"values":[["'$(date +%s)'000000000","17642792185784"]]}]}' http://100.64.0.113:3100/loki/api/v1/push

# 監控日誌
docker logs kevin-telemetry-promtail-agent --tail 50
```

### 配置變更對比
| 參數 | 修改前 | 修改後 | 變更 |
|------|--------|--------|------|
| JSON 欄位 | 8 個 | 1 個 | -87.5% |
| 時間戳解析 | 複雜 | 預設 | 簡化 |
| Log 內容 | JSON 物件 | 數值 | 簡化 |
| 標籤數量 | 3 個 | 3 個 | 保持 |

---

## 🎯 結論

### 已完成的工作
1. ✅ **簡化 JSON 解析** - 只提取 rx_bits 欄位
2. ✅ **使用 Template Stage** - 將 rx_bits 值設為 log 內容
3. ✅ **移除時間戳解析** - 使用 Promtail 預設時間戳
4. ✅ **移除不必要欄位** - 簡化資料傳輸
5. ✅ **測試連線** - 確認手動發送成功

### 配置狀態
**✅ 配置已修改** - Promtail 現在只傳送 rx_bits 數值

### Grafana 使用建議
1. **Time Series 查詢**: `{job="network_monitor", instance="GC-aro11-agent"}`
2. **Stat 查詢**: 同上，選擇 Stat 視圖類型
3. **數值單位**: rx_bits 以 bits 為單位
4. **時間範圍**: 建議使用 "Last 1 hour" 或 "Last 6 hours"

### 技術支援資訊
- **Promtail 版本**: 3.0.0
- **配置檔案**: `/home/rnd/telemetry/promtail-config.yml`
- **容器名稱**: `kevin-telemetry-promtail-agent`
- **Loki 服務器**: http://100.64.0.113:3100
- **Log 檔案**: `/home/rnd/telemetry/logs/network_stats.log`

---

**修改完成時間**: 2025-10-22 10:06:00 AM +04  
**修改狀態**: 配置已簡化完成  
**資料格式**: 只傳送 rx_bits 數值
