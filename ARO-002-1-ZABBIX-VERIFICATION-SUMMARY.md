# ARO-002-1 Agent Zabbix 資料驗證摘要

**驗證時間**: 2025-11-28  
**驗證腳本**: `verify-aro-002-1-zabbix-data.sh`

## 驗證結果

### ✅ 成功項目

1. **Zabbix API 連線**: ✅ 成功
   - URL: http://100.64.0.113:8080/api_jsonrpc.php
   - 認證成功

2. **Host 存在**: ✅ 找到
   - Host ID: 10648
   - Host Name: GC-ARO-002-1-agent
   - Status: 0 (enabled)

3. **網路監控項目**: ✅ 找到
   - 找到 1 個網路介面項目
   - Item: "Interface enp86s0: Bits received (Rate)"
   - Item Key: `net.if.in["enp86s0"]`
   - Item ID: 48451

### ⚠️ 需要注意的問題

1. **Host 可用性狀態**: ⚠️ null
   - Available 狀態為 null（應該是 1=available）
   - 可能表示 agent 尚未完全連接到 server
   - 或需要等待一段時間讓狀態更新

2. **資料收集狀態**: ⚠️ 無資料
   - Last Value: 0
   - Last Clock: null（無時間戳記）
   - State: 1 (not supported)
   - 沒有歷史資料

3. **網路介面不一致**: ⚠️
   - Zabbix Server 中配置的是 `enp86s0`
   - Agent 實際可以取得 `eth0` 的資料
   - Dashboard 查詢的是 `eth0`

## 驗證腳本使用方式

### 執行驗證

```bash
cd /home/rnd/telemetry
./verify-aro-002-1-zabbix-data.sh
```

### 自訂參數

```bash
# 指定不同的 Zabbix URL
ZABBIX_URL="http://100.64.0.113:8080/api_jsonrpc.php" ./verify-aro-002-1-zabbix-data.sh

# 指定不同的認證資訊
ZABBIX_USER="admin" ZABBIX_PASSWORD="admin" ./verify-aro-002-1-zabbix-data.sh
```

## 問題分析

### 問題 1: Host Available 狀態為 null

**可能原因**:
- Agent 剛啟動，Zabbix Server 尚未完成狀態檢查
- Agent 與 Server 之間的連線尚未建立
- Zabbix Server 配置問題

**解決方法**:
1. 等待 5-10 分鐘讓 Zabbix Server 完成狀態檢查
2. 檢查 Agent 容器日誌：
   ```bash
   docker logs telemetry-zabbix-agent-GC-aro21-agent | tail -50
   ```
3. 檢查 Zabbix Server 連線：
   ```bash
   # 在 Server 端檢查
   telnet 100.64.0.113 10051
   ```

### 問題 2: 資料值為 0 且無時間戳記

**可能原因**:
- Item 狀態為 "not supported" (state=1)
- Agent 無法取得該項目的資料
- Item 配置不正確

**解決方法**:
1. 檢查 Agent 是否可以取得資料：
   ```bash
   docker exec telemetry-zabbix-agent-GC-aro21-agent zabbix_agent2 -t 'net.if.in[eth0]'
   docker exec telemetry-zabbix-agent-GC-aro21-agent zabbix_agent2 -t 'net.if.in[enp86s0]'
   ```

2. 檢查 Zabbix Server 中的 Item 配置：
   - 登入 Zabbix Web UI: http://100.64.0.113:8080
   - 檢查 Configuration > Hosts > GC-ARO-002-1-agent > Items
   - 確認 Item 是否啟用
   - 檢查 Item Key 是否正確

### 問題 3: 網路介面不一致

**問題描述**:
- Zabbix Server 中配置的是 `enp86s0`
- Agent 實際可以取得 `eth0` 的資料
- Grafana Dashboard 查詢的是 `eth0`

**解決方法**:
1. 在 Zabbix Server 中新增 `eth0` 的監控項目
2. 或修改 Dashboard 查詢為 `enp86s0`
3. 確認 Agent 實際使用的網路介面名稱

## 後續步驟

### 1. 等待並重新驗證

```bash
# 等待 10 分鐘後重新執行驗證
sleep 600
./verify-aro-002-1-zabbix-data.sh
```

### 2. 檢查 Agent 端狀態

```bash
# 檢查容器狀態
docker ps | grep aro21-agent

# 檢查 Agent 日誌
docker logs telemetry-zabbix-agent-GC-aro21-agent -f

# 測試 Agent 資料收集
docker exec telemetry-zabbix-agent-GC-aro21-agent zabbix_agent2 -t 'net.if.in[eth0]'
docker exec telemetry-zabbix-agent-GC-aro21-agent zabbix_agent2 -t 'net.if.out[eth0]'
```

### 3. 檢查 Zabbix Server 端

1. 登入 Zabbix Web UI: http://100.64.0.113:8080
2. 檢查 Host 狀態：
   - Configuration > Hosts > GC-ARO-002-1-agent
   - 確認 Agent 狀態為 "Available"（綠色）
3. 檢查 Items：
   - 確認網路流量相關的 Items 是否啟用
   - 檢查 Item 的 "Last check" 時間
   - 確認 Item 狀態為 "Normal"

### 4. 在 Grafana 中驗證

1. 登入 Grafana: http://100.64.0.113:3000
2. 開啟 Dashboard: System Overview
3. 查看 "Network Traffic - All Agents (MBps)" panel
4. 確認 ARO21 的資料線是否出現

## 驗證腳本輸出說明

腳本會顯示以下資訊：

1. **認證狀態**: Zabbix API 認證是否成功
2. **Host 狀態**: Host 是否存在、是否啟用、是否可用
3. **網路項目**: 找到的網路監控項目列表
4. **資料狀態**: 最後資料值、最後更新時間、資料新鮮度
5. **歷史資料**: 過去 1 小時的歷史資料記錄數

## 預期正常狀態

當一切正常時，驗證腳本應該顯示：

- ✅ Host Status: Available (1)
- ✅ Network Items: Found (至少 2 個：RX 和 TX)
- ✅ Data Freshness: Recent (少於 10 分鐘)
- ✅ History Records: 有資料（過去 1 小時）

## 相關檔案

- `verify-aro-002-1-zabbix-data.sh` - 驗證腳本
- `ARO-002-1-VERIFICATION-REPORT.md` - Agent 端驗證報告
- `GRAFANA-DASHBOARD-QUERY-GUIDE.md` - Grafana 查詢指南

