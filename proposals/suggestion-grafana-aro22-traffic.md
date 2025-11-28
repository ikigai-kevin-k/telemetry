# Grafana Dashboard 修改建議：ARO22 Network Traffic Panel

## 📋 背景與問題描述

**問題**：Grafana dashboard 中的 "Network Traffic - All Agents (MBps)" panel 目前只顯示 ARO12 的數據，缺少 ARO11、ARO21、ARO22、ASB11 的查詢配置。特別是 ARO22 的 network traffic 顯示為 0 或 Kb 等級，而其他 agents 正常顯示 6-7 Mbps。

**影響範圍**：
- Grafana dashboard: `grafana/provisioning/dashboards/general/overview.json`
- Panel: "Network Traffic - All Agents (MBps)" (id: 12)
- 目前只有 ARO12 的查詢配置，需要添加其他 4 個 agents 的查詢

## 🔍 根因分析

1. **Dashboard 配置不完整**：Network Traffic panel 目前只有一個查詢（ARO12），缺少其他 agents 的查詢配置
2. **Zabbix Item 名稱**：所有 agents 都應該使用相同的 item 名稱 "Interface enp86s0: Bits received"
3. **Host 名稱對應**：
   - ARO11 → `GC-aro11-agent`
   - ARO12 → `GC-aro12-agent`
   - ARO21 → `GC-aro21-agent`
   - ARO22 → `GC-ARO-002-2-agent`
   - ASB11 → `GC-ASB-001-1-agent`

## 💡 建議修改方案

### 修改檔案
`grafana/provisioning/dashboards/general/overview.json`

### 修改位置
Panel ID: 12, Title: "Network Traffic - All Agents (MBps)"
Section: `targets` array (目前只有一個查詢，需要擴展為 5 個)

### 具體修改內容

在 `targets` array 中添加 5 個查詢配置，每個查詢對應一個 agent：

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

#### 2. ARO12 (refId: B)
（保持現有配置，只需將 refId 改為 "B"）

#### 3. ARO21 (refId: C)
（與 ARO11 相同，但 host 改為 `GC-aro21-agent`，alias 改為 `ARO21`）

#### 4. ARO22 (refId: D)
（與 ARO11 相同，但 host 改為 `GC-ARO-002-2-agent`，alias 改為 `ARO22`）

#### 5. ASB11 (refId: E)
（與 ARO11 相同，但 host 改為 `GC-ASB-001-1-agent`，alias 改為 `ASB11`）

### 完整 targets 結構

將現有的單一查詢擴展為包含 5 個查詢的 array，每個查詢使用不同的：
- `refId`: A, B, C, D, E
- `host.filter`: 對應的 agent hostname
- `functions[0].params[0]`: 對應的 alias (ARO11, ARO12, ARO21, ARO22, ASB11)

## ✅ 驗證步驟

1. **檢查 Zabbix Server Items**：
   - 確認所有 5 個 agents 在 Zabbix server 端都有 "Interface enp86s0: Bits received" 這個 item
   - 如果沒有，需要等待 Zabbix 自動發現或手動創建 items

2. **重啟 Grafana 容器**：
   ```bash
   docker restart <grafana-container-name>
   ```

3. **驗證 Dashboard**：
   - 打開 Grafana dashboard
   - 檢查 "Network Traffic - All Agents (MBps)" panel
   - 確認所有 5 條線（ARO11, ARO12, ARO21, ARO22, ASB11）都正常顯示
   - 確認 ARO22 的數值約為 6-7 Mbps（與其他 agents 一致）

4. **檢查數據**：
   - 確認所有 agents 的 network traffic 數據都在正常範圍內（約 6-7 Mbps）
   - 確認沒有數據為 0 或異常低的情況

## ⚠️ 注意事項

1. **Zabbix Item 依賴**：
   - 此修改假設 Zabbix server 端已經有對應的 items
   - 如果 Zabbix 使用自動發現（LLD），items 應該會自動創建
   - 如果沒有自動發現，需要在 Zabbix server 端手動創建 items

2. **Host 名稱一致性**：
   - 確保 Grafana 中的 host 名稱與 Zabbix server 中的 host 名稱完全一致
   - ARO22 的 host 名稱是 `GC-ARO-002-2-agent`（注意大小寫和連字符）

3. **Item 名稱**：
   - 所有 agents 都使用相同的 item 名稱："Interface enp86s0: Bits received"
   - 這是 Zabbix 自動發現創建的標準 item 名稱

4. **JSON 格式**：
   - 修改時注意保持 JSON 格式正確
   - 建議使用 JSON linter 驗證格式

## 🔄 回滾方案

如果修改後出現問題，可以：
1. 使用 Git 還原修改：`git checkout grafana/provisioning/dashboards/general/overview.json`
2. 或手動移除新增的查詢，只保留 ARO12 的查詢

## 📝 相關檔案

- Agent-side 配置已完成：
  - `/home/rnd/telemetry/zabbix/agent2-GC-ARO-002-2-agent.conf` - 已添加 `custom.net.if.*` 參數
  - `/home/rnd/telemetry/zabbix/scripts/network_monitor.sh` - 已更新支援容器環境

- Server-side 需要修改：
  - `/home/rnd/telemetry/grafana/provisioning/dashboards/general/overview.json` - 此檔案

## 🎯 預期結果

修改完成後，Grafana dashboard 的 Network Traffic panel 應該顯示：
- ✅ 5 條數據線（ARO11, ARO12, ARO21, ARO22, ASB11）
- ✅ 所有 agents 的 network traffic 都在 6-7 Mbps 範圍內
- ✅ ARO22 不再顯示為 0 或 Kb 等級

