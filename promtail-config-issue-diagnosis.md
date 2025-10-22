# Promtail 配置修改問題診斷報告

## 📋 問題概要

**問題描述**: Grafana 中顯示的資料格式仍然是完整的 JSON 物件，而不是期望的簡化 `rx_bits` 數值  
**發現時間**: 2025-10-22 10:16 (UTC+4)  
**狀態**: 配置修改未生效  

---

## 🔍 診斷結果

### ✅ 已確認正常的部分
1. **Promtail 容器運行正常** - 容器狀態正常
2. **Network monitor 目標已添加** - 日誌顯示成功添加 `GC-aro11-agent` 目標
3. **Network_stats.log 檔案存在** - 檔案正在持續更新
4. **Loki 連線正常** - 手動發送測試成功
5. **配置語法正確** - Promtail 配置驗證通過

### ❌ 問題所在
**Promtail 沒有成功處理和發送 network_stats.log 的資料**

從 Promtail 日誌中可以看到：
- ✅ 成功添加目標：`Adding target key="/var/log/network_stats.log:{instance=\"GC-aro11-agent\", interface=\"enp86s0\", job=\"network_monitor\"}"`
- ✅ 開始監控檔案：`tail routine: started path=/var/log/network_stats.log`
- ❌ **沒有看到任何 JSON 解析或資料發送的記錄**

---

## 🛠️ 嘗試過的修改

### 修改 1: 簡化 JSON 解析
```yaml
pipeline_stages:
  - json:
      expressions:
        rx_bits: rx_bits
  - template:
      source: rx_bits
      template: '{{ .rx_bits }}'
```

### 修改 2: 使用 output stage
```yaml
pipeline_stages:
  - json:
      expressions:
        rx_bits: rx_bits
  - output:
      source: rx_bits
```

### 修改 3: 只使用 JSON 解析
```yaml
pipeline_stages:
  - json:
      expressions:
        rx_bits: rx_bits
```

**結果**: 所有修改都沒有生效，Grafana 中仍然顯示完整 JSON 格式

---

## 🎯 根本原因分析

### 可能的原因
1. **Promtail 版本問題** - 使用 `grafana/promtail:3.0.0` 可能有兼容性問題
2. **配置載入問題** - 配置修改沒有正確載入
3. **檔案監控問題** - Promtail 沒有檢測到新的 log 條目
4. **JSON 解析問題** - Promtail 無法正確解析 JSON 格式

### 證據
- Promtail 日誌中沒有 JSON 解析記錄
- 沒有資料發送記錄
- Grafana 中顯示的仍然是原始 JSON 格式

---

## 🔧 建議解決方案

### 方案 1: 升級 Promtail 版本
```yaml
# docker-compose.agent.yml
image: grafana/promtail:latest
```

### 方案 2: 檢查配置載入
```bash
# 檢查配置是否正確載入
docker exec kevin-telemetry-promtail-agent cat /etc/promtail/config.yml
```

### 方案 3: 使用不同的 pipeline stage
```yaml
pipeline_stages:
  - json:
      expressions:
        rx_bits: rx_bits
  - labels:
      rx_bits:
  - match:
      selector: '{job="network_monitor"}'
      stages:
        - output:
            source: rx_bits
```

### 方案 4: 手動測試配置
```bash
# 手動觸發新的 log 條目
echo '{"rx_bits": 123456789}' >> logs/network_stats.log
```

---

## 📊 當前狀態

| 項目 | 狀態 | 說明 |
|------|------|------|
| Promtail 容器 | ✅ 正常 | 運行中 |
| 配置載入 | ✅ 正常 | 語法正確 |
| 目標添加 | ✅ 正常 | GC-aro11-agent 已添加 |
| 檔案監控 | ✅ 正常 | network_stats.log 正在監控 |
| JSON 解析 | ❌ 失敗 | 沒有解析記錄 |
| 資料發送 | ❌ 失敗 | 沒有發送記錄 |
| Grafana 顯示 | ❌ 錯誤 | 仍顯示完整 JSON |

---

## 🎯 下一步行動

### 立即行動
1. **升級 Promtail 版本** - 從 3.0.0 升級到 latest
2. **檢查配置載入** - 確認配置正確載入
3. **測試 JSON 解析** - 手動觸發新的 log 條目

### 持續監控
1. **檢查 Promtail 日誌** - 尋找 JSON 解析記錄
2. **檢查 Grafana 顯示** - 確認資料格式是否改變
3. **驗證資料傳輸** - 確認資料是否成功發送到 Loki

---

**診斷完成時間**: 2025-10-22 10:16:00 AM +04  
**問題狀態**: 配置修改未生效  
**下一步**: 升級 Promtail 版本並重新測試
