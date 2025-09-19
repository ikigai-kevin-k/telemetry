# Grafana Zabbix Dashboard 整合指南

## 📋 概述

本文件記錄了成功整合 Grafana 與 Zabbix 監控系統的完整步驟，包括問題排除和解決方案。

## 🏗️ 架構說明

### Docker 容器配置
- **Grafana**: 版本 9.5.21，運行在 172.18.0.8:3000
- **Zabbix Web**: 版本 6.0，運行在 172.18.0.7:8080  
- **Zabbix Server**: 版本 6.0，運行在 172.18.0.6:10051
- **Zabbix DB**: MySQL 8.0，運行在 172.18.0.4:3306

### 網路配置
所有服務運行在 `telemetry_monitoring` bridge 網路中，IP 範圍：172.18.0.0/16

## 🔧 問題解決步驟

### 問題 1: Zabbix 資料源連線錯誤

**錯誤訊息**: `dial tcp 172.18.0.4:8080: connect: connection refused`

**原因**: 初始配置錯誤地嘗試連接到 Zabbix DB (172.18.0.4) 而不是 Zabbix Web

**解決方案**:
```yaml
# grafana/provisioning/datasources/zabbix.yml
datasources:
  - name: Zabbix-New
    type: alexanderzobnin-zabbix-datasource
    access: proxy
    url: http://172.18.0.7:8080  # 正確的 Zabbix Web IP
```

### 問題 2: JSON 解析錯誤

**錯誤訊息**: `invalid character '<' looking for beginning of value`

**原因**: Grafana 期望 JSON API 回應，但收到 HTML 登入頁面

**解決方案**: 修正 URL 為完整 API 端點
```yaml
url: http://172.18.0.7:8080/api_jsonrpc.php  # 完整 API 路徑
```

### 問題 3: React 插件錯誤

**錯誤訊息**: `Minified React error #130`

**原因**: Zabbix 插件版本與 Grafana 版本不相容
- Grafana 9.5.21 與 Zabbix 插件 4.6.1+ 不相容
- 需要 Grafana 10.2.3+ 才能支援 Zabbix 插件 4.6.0+

**解決方案**: 安裝相容的插件版本
```bash
# 卸載不相容版本
docker exec kevin-telemetry-grafana grafana-cli plugins uninstall alexanderzobnin-zabbix-app

# 安裝相容版本
docker exec kevin-telemetry-grafana grafana-cli plugins install alexanderzobnin-zabbix-app 4.5.1

# 重新啟動 Grafana
docker restart kevin-telemetry-grafana
```

## ✅ 最終工作配置

### Zabbix 資料源設定
```yaml
# grafana/provisioning/datasources/zabbix.yml
apiVersion: 1
datasources:
  - name: Zabbix-New
    type: alexanderzobnin-zabbix-datasource
    access: proxy
    url: http://172.18.0.7:8080/api_jsonrpc.php
    basicAuth: false
    isDefault: false
    jsonData:
      username: Admin
      cacheTTL: 300s
      timeout: 30
      trends: true
      trendsFrom: 7d
      trendsRange: 4d
      addThresholds: false
      alerting: false
      disableDataAlignment: false
      disableReadOnlyUsersAck: false
      httpMode: POST
      queryMode: Metrics
      tlsSkipVerify: true
    secureJsonData:
      password: zabbix
    editable: true
```

### 插件版本相容性
| Grafana 版本 | 相容的 Zabbix 插件版本 |
|-------------|---------------------|
| 9.5.x       | 4.5.1 (推薦)        |
| 10.2.3+     | 4.6.0+             |

## 📊 Dashboard 配置

### 成功建立的監控面板

1. **CPU 使用率**
   - 監控項目: Linux Load average (1m, 5m, 15m avg)
   - 可視化: Time series
   - 多主機支援

2. **記憶體使用率**
   - 監控項目: Linux Memory utilization
   - 可視化: Time series  
   - 單位: 百分比 (%)

3. **磁碟使用率**
   - 監控項目: /etc/hosts Space utilization
   - 可視化: Time series
   - 單位: 百分比 (%)

4. **系統運行時間**
   - 監控項目: Linux System uptime
   - 可視化: Time series
   - 單位: 天數

### 查詢配置範例
```
Data source: Zabbix-New
Query type: Metrics
Group: Linux servers
Host: /* (萬用字元，支援多主機)
Item: Linux: Load average (1m avg)
Functions: (通常留空)
```

## 🔄 持久化儲存

### Docker Volume 配置
```yaml
# docker-compose.yml
services:
  grafana:
    volumes:
      - grafana_data:/var/lib/grafana              # Dashboard 和設定
      - ./grafana/provisioning:/etc/grafana/provisioning  # 資料源配置
      - ./grafana/grafana.ini:/etc/grafana/grafana.ini    # Grafana 設定

volumes:
  grafana_data:  # 持久化 Dashboard、用戶設定、插件等
```

### 備份重要檔案
- `grafana/provisioning/datasources/zabbix.yml` - 資料源配置
- `grafana/provisioning/dashboards/` - Dashboard 定義
- Docker volume `telemetry_grafana_data` - 使用者資料和設定

## 🚀 驗證步驟

1. **檢查容器狀態**
   ```bash
   docker ps --filter "name=zabbix\|grafana"
   ```

2. **驗證網路連線**
   ```bash
   curl -I http://172.18.0.7:8080/api_jsonrpc.php
   ```

3. **測試 API 連線**
   ```bash
   curl -s http://172.18.0.7:8080/api_jsonrpc.php \
     -H "Content-Type: application/json" \
     -d '{"jsonrpc":"2.0","method":"apiinfo.version","params":{},"id":1}'
   ```

4. **確認插件版本**
   ```bash
   docker exec kevin-telemetry-grafana grafana-cli plugins ls | grep zabbix
   ```

## 📈 監控主機清單

目前配置的監控主機：
- **Zabbix server** (hostid: 10084)
- **GC-ARO-001-2-agent** (hostid: 10643)
- **GC-ASB-001-1-agent**
- **GC-ARO-001-1-agent**  
- **GC-ARO-002-2-agent**
- **GC-ARO-002-1-agent**

## 🔍 故障排除

### 常見問題和解決方案

1. **"No data" 顯示**
   - 檢查時間範圍設定
   - 確認監控項目有資料
   - 驗證主機狀態

2. **連線超時**
   - 檢查網路連通性
   - 確認防火牆設定
   - 驗證 Zabbix 服務狀態

3. **插件載入失敗**
   - 檢查插件版本相容性
   - 重新安裝插件
   - 重啟 Grafana 服務

## 📝 維護建議

1. **定期備份**
   - 定期備份 Docker volumes
   - 匯出重要的 Dashboard 設定
   - 保存 provisioning 配置檔案

2. **監控健康狀態**
   - 定期檢查容器狀態
   - 監控磁碟空間使用
   - 檢查日誌檔案

3. **版本更新**
   - 更新前先備份資料
   - 檢查版本相容性
   - 測試環境先行驗證

---

**建立日期**: 2025-09-19  
**最後更新**: 2025-09-19  
**狀態**: ✅ 生產環境運行中
