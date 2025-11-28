# Grafana Dashboard Network Traffic Panel 修改建議

## 📋 背景與問題描述

**問題**: Grafana server 上的 "AIPC Network Traffic - All Agents (MBps)" panel 中，ARO22 (orange line) 的 traffic metric 顯示為 Kb 等級，遠小於其他 agents 的 Mb 等級（正常應該在 6Mb/s 附近）。

**根本原因**: 
1. ✅ **Agent-side 已修復**: aro22 agent 的 Zabbix agent 配置已添加 `custom.net.if.*` 參數，並更新了 `network_monitor.sh` 腳本以支援容器環境
2. ⚠️ **Server-side 待修復**: Grafana dashboard 的 Network Traffic panel 目前只配置了 ARO12 的查詢，缺少其他 agents（ARO11, ARO21, ARO22, ASB11）的查詢配置

## 🔍 影響範圍

- **Dashboard**: `grafana/provisioning/dashboards/general/overview.json`
- **Panel**: "Network Traffic - All Agents (MBps)" (id: 12)
- **受影響的 Agents**: ARO11, ARO21, ARO22, ASB11（目前沒有查詢配置）

## 💡 建議修改內容

### 修改檔案
`grafana/provisioning/dashboards/general/overview.json`

### 修改位置
Panel ID 12 的 `targets` 陣列（目前只有一個查詢，需要擴展為 5 個）

### 具體修改

在 `targets` 陣列中添加以下查詢配置：

#### 1. ARO11 (refId: A)
```json
{
  "application": {
    "filter": ""
  },
  "countTriggersBy": "",
  "datasource": {
    "type": "alexanderzobnin-zabbix-datasource",
    "uid": "zabbix-datasource"
  },
  "evaltype": "0",
  "functions": [
    {
      "added": true,
      "def": {
        "category": "Alias",
        "defaultParams": [],
        "name": "setAlias",
        "params": [
          {
            "name": "alias",
            "type": "string"
          }
        ]
      },
      "params": [
        "ARO11"
      ],
      "text": "setAlias()"
    }
  ],
  "group": {
    "filter": "Linux servers"
  },
  "host": {
    "filter": "GC-aro11-agent"
  },
  "item": {
    "filter": "Interface enp86s0: Bits received"
  },
  "itemTag": {
    "filter": "interface: eth0"
  },
  "key": "Q-cc99a50f-83e8-4c03-a846-8ac3a4169e46-0",
  "macro": {
    "filter": ""
  },
  "options": {
    "count": false,
    "disableDataAlignment": false,
    "showDisabledItems": false,
    "skipEmptyValues": false,
    "useTrends": "default",
    "useZabbixValueMapping": false
  },
  "proxy": {
    "filter": ""
  },
  "queryType": "0",
  "refId": "A",
  "resultFormat": "time_series",
  "schema": 12,
  "table": {
    "skipEmptyValues": false
  },
  "tags": {
    "filter": ""
  },
  "textFilter": "",
  "trigger": {
    "filter": ""
  }
}
```

#### 2. ARO12 (refId: B) - 已存在，只需更新 refId
將現有的 ARO12 查詢的 `refId` 從 `"A"` 改為 `"B"`

#### 3. ARO21 (refId: C)
與 ARO11 相同配置，但：
- `host.filter`: `"GC-aro21-agent"`
- `functions[0].params[0]`: `"ARO21"`
- `refId`: `"C"`

#### 4. ARO22 (refId: D) - **關鍵修復**
與 ARO11 相同配置，但：
- `host.filter`: `"GC-ARO-002-2-agent"` ⚠️ **注意**: 使用 `GC-ARO-002-2-agent` 而不是 `GC-aro22-agent`
- `functions[0].params[0]`: `"ARO22"`
- `refId`: `"D"`
- `item.filter`: `"Interface enp86s0: Bits received"` ⚠️ **注意**: 使用 `enp86s0` 而不是 `eth0`

#### 5. ASB11 (refId: E)
與 ARO11 相同配置，但：
- `host.filter`: `"GC-ASB-001-1-agent"`
- `functions[0].params[0]`: `"ASB11"`
- `refId`: `"E"`

## ✅ 驗證步驟

### 1. 確認 Zabbix Server 端 Items 存在
在 Zabbix server 端確認以下 hosts 都有對應的 item：
- `GC-aro11-agent`: `Interface enp86s0: Bits received`
- `GC-aro12-agent`: `Interface enp86s0: Bits received`
- `GC-aro21-agent`: `Interface enp86s0: Bits received`
- `GC-ARO-002-2-agent`: `Interface enp86s0: Bits received` ⚠️ **關鍵**
- `GC-ASB-001-1-agent`: `Interface enp86s0: Bits received`

### 2. 重啟 Grafana 容器
```bash
docker restart <grafana-container-name>
```

### 3. 檢查 Dashboard
1. 打開 Grafana dashboard "AIPC Network Traffic - All Agents (MBps)"
2. 確認所有 5 條線（ARO11, ARO12, ARO21, ARO22, ASB11）都顯示數據
3. 確認 ARO22 的數值約為 6-7 Mb/s（與其他 agents 一致）

### 4. 驗證 ARO22 數據
- ARO22 的數據應該從 0 b/s 或 Kb 等級提升到 6-7 Mb/s
- 所有 agents 的數據應該在同一範圍內（6-7 Mb/s）

## ⚠️ 注意事項

1. **Host 名稱**: ARO22 的 host 名稱是 `GC-ARO-002-2-agent`（大寫），不是 `GC-aro22-agent`
2. **Interface 名稱**: 所有 agents 都使用 `enp86s0` 介面，不是 `eth0`
3. **Item 名稱**: 必須是 `Interface enp86s0: Bits received`，這是 Zabbix server 端自動發現或手動創建的 item 名稱
4. **Zabbix Server 端配置**: 如果 Zabbix server 端還沒有對應的 items，需要：
   - 等待自動發現（LLD）創建 items
   - 或手動創建 items，使用 key: `custom.net.if.in.rate[enp86s0]`

## 🔄 回滾方案

如果修改後出現問題，可以：
1. 還原 `overview.json` 到修改前的版本
2. 重啟 Grafana 容器
3. 檢查 Zabbix server 端的 items 配置

## 📝 相關檔案

- Agent-side 修改已完成：
  - `zabbix/agent2-GC-ARO-002-2-agent.conf` - 已添加 `custom.net.if.*` 參數
  - `zabbix/scripts/network_monitor.sh` - 已更新支援容器環境

- Server-side 待修改：
  - `grafana/provisioning/dashboards/general/overview.json` - 需要添加所有 agents 的查詢配置

## 🎯 預期結果

修改完成後，Grafana dashboard 應該顯示：
- ✅ 所有 5 個 agents 的 network traffic 數據
- ✅ ARO22 的數據從 Kb 等級提升到 Mb 等級（6-7 Mb/s）
- ✅ 所有 agents 的數據在同一範圍內，圖表顯示正常

---

**建立時間**: 2025-11-28  
**建立者**: Agent-side (aro22)  
**目標端別**: Server-side  
**優先級**: 高（影響監控數據顯示）

