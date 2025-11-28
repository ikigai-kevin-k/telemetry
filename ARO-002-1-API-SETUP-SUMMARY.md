# ARO-002-1 Network Traffic Items - API Setup Summary

**日期**: 2025-11-28  
**狀態**: ⚠️ **部分完成** - 需要手動完成部分步驟

## 已完成的工作

### 1. Agent 端配置 ✅
- ✅ 已更新 `zabbix/agent2-GC-ARO-002-1-agent.conf`
- ✅ 新增自定義 UserParameter：
  - `custom.net.if.in.bytes[*]` - 映射 eth0 到 enp86s0 (RX)
  - `custom.net.if.out.bytes[*]` - 映射 eth0 到 enp86s0 (TX)
- ✅ Agent 容器已重啟並正常運行
- ✅ 驗證新的 keys 可以正常讀取數據

### 2. Zabbix Server 端 Items 狀態

#### RX Item (接收流量)
- **Item ID**: 48453
- **名稱**: Interface eth0: Bits received
- **Key**: `custom.net.if.in.bytes[eth0]` ✅ (已更新)
- **Preprocessing**: 
  - 目前: type "10" (Simple change) + type "1" (Multiply, params: "8")
  - 需要: type "1" (Change per second) + type "6" (Multiply, params: "8")

#### TX Item (發送流量)
- **狀態**: ❌ 尚未創建
- **需要創建**: Item with key `custom.net.if.out.bytes[eth0]`

## 需要完成的工作

### 方法 1: 透過 Zabbix Web UI（推薦）

1. **更新 RX Item 的 Preprocessing**:
   - 登入 Zabbix Web UI: http://100.64.0.113:8080
   - 導航至: Configuration > Hosts > GC-ARO-002-1-agent > Items
   - 找到 Item: "Interface eth0: Bits received" (ID: 48453)
   - 點擊編輯
   - 在 "Preprocessing" 標籤頁：
     - 刪除現有的 preprocessing steps
     - 新增 Step 1: "Change per second" (type 1)
     - 新增 Step 2: "Multiply" (type 6), params: "8"
   - 儲存

2. **創建 TX Item**:
   - 在相同頁面，點擊 "Create item"
   - 配置：
     - **Name**: Interface eth0: Bits sent
     - **Key**: `custom.net.if.out.bytes[eth0]`
     - **Type**: Zabbix agent
     - **Type of information**: Numeric (unsigned)
     - **Units**: `bps`
     - **Update interval**: 30s
     - **Preprocessing**:
       - Step 1: Change per second (type 1)
       - Step 2: Multiply (type 6), params: "8"
   - 儲存

### 方法 2: 透過 API（需要進一步調試）

由於 Zabbix API 的 `item.create` 和 `item.update` 在處理 preprocessing 時遇到格式問題，建議使用 Web UI 完成剩餘配置。

如果必須使用 API，可以參考以下步驟：

1. **更新 RX Item Preprocessing**:
```bash
curl -X POST "http://100.64.0.113:8080/api_jsonrpc.php" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "item.update",
    "params": {
      "itemid": "48453",
      "preprocessing": [
        {
          "type": "1",
          "params": "",
          "error_handler": "0",
          "error_handler_params": ""
        },
        {
          "type": "6",
          "params": "8",
          "error_handler": "0",
          "error_handler_params": ""
        }
      ]
    },
    "auth": "<AUTH_TOKEN>",
    "id": 1
  }'
```

2. **創建 TX Item**:
   - 由於 `item.create` API 調用遇到格式問題，建議使用 Web UI 創建

## 驗證步驟

完成配置後，執行以下驗證：

1. **在 Agent 端驗證**:
```bash
docker exec telemetry-zabbix-agent-GC-aro21-agent zabbix_agent2 -t "custom.net.if.in.bytes[eth0]"
docker exec telemetry-zabbix-agent-GC-aro21-agent zabbix_agent2 -t "custom.net.if.out.bytes[eth0]"
```

2. **在 Zabbix Server 端驗證**:
```bash
zabbix_get -s 100.64.0.143 -k "custom.net.if.in.bytes[eth0]"
zabbix_get -s 100.64.0.143 -k "custom.net.if.out.bytes[eth0]"
```

3. **在 Grafana 中驗證**:
   - 登入 Grafana: http://100.64.0.113:3000
   - 開啟 "AIPC Network Traffic - All Agents (MBps)" dashboard
   - 確認 ARO21 的資料線顯示正常（約 6-7 Mbps）

## 相關檔案

- `zabbix/agent2-GC-ARO-002-1-agent.conf` - Agent 配置（已更新）✅
- `create-aro-002-1-network-items.sh` - 創建 items 的腳本（遇到 API 格式問題）
- `update-aro-002-1-network-items.sh` - 更新 items 的腳本（部分成功）

## 注意事項

1. **Grafana Dashboard 更新**:
   - 如果 Grafana dashboard 使用 Item 名稱而非 Key 來查詢，可能不需要更新
   - 如果使用 Key 查詢，需要更新 dashboard 配置以使用新的 keys

2. **同樣的問題可能存在於 ARO-002-2**:
   - 需要對 `zabbix/agent2-GC-ARO-002-2-agent.conf` 進行相同的修改
   - 並在 Zabbix Server 端創建/更新相應的 items

