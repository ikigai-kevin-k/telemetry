# Fix: ARO12 Network Traffic Missing in Grafana Dashboard - Server-side Configuration

**日期**: 2025-11-28 13:05  
**問題主機**: `GC-aro12-agent` (ARO12)  
**影響範圍**: Grafana dashboard "AIPC Network Traffic - All Agents (MBps)" 中 ARO12 的網路流量數據消失

## 背景與問題描述

### 問題狀態

1. ✅ **Agent-side 修復已完成**：
   - `network_monitor.sh` 已更新，支援讀取 `/host/proc/net/dev`
   - `docker-compose-GC-aro12-agent.yml` 已添加 mount `/proc/net/dev:/host/proc/net/dev:ro`
   - Agent 容器已重新創建並正常運行
   - `net.if.in[enp86s0]` 可以正常查詢（返回累計 bytes 值）

2. ❌ **Grafana Dashboard 中 ARO12 數據消失**：
   - Grafana dashboard 查詢的 Item: "Interface enp86s0: Bits received"
   - 對應的 Zabbix key: `net.if.in["enp86s0"]`
   - 其他 agents (ARO11, ARO21, ARO22, ASB11) 正常顯示
   - 只有 ARO12 的數據線消失

### 關鍵觀察

- Agent 端 `net.if.in[enp86s0]` 可以正常查詢並返回數據
- Grafana dashboard 配置正確（Item: "Interface enp86s0: Bits received"）
- 問題可能出在 Zabbix Server 端的 Item 配置

## 影響範圍與根因推測

### 可能原因（依優先順序）

1. **Zabbix Server 端 Item 不存在或未啟用**
   - Item "Interface enp86s0: Bits received" 可能不存在於 `GC-aro12-agent` host
   - 或者 Item 存在但被停用

2. **Item 的 Key 配置錯誤**
   - Item 的 key 可能不是 `net.if.in["enp86s0"]`
   - 或者 key 格式不正確

3. **Item 的 Preprocessing 配置錯誤**
   - 需要 "Change per second" preprocessing 來計算速率
   - 需要 "Multiply by 8" preprocessing 來轉換為 bits per second
   - 如果 preprocessing 配置錯誤，數據可能無法正確顯示

4. **Item 的 Units 配置錯誤**
   - Units 應該設置為 `bps` (bits per second)
   - 如果設置為 `B` (bytes) 或其他單位，可能導致顯示問題

## Server-side 修改建議

### 方案：檢查並修正 Zabbix Server 端 Item 配置

#### 步驟 1：檢查 Item 是否存在

在 Zabbix Server 端執行：

```bash
# 使用 Zabbix API 檢查 Item
curl -X POST http://100.64.0.113:8080/api_jsonrpc.php \
  -H 'Content-Type: application/json-rpc' \
  -d '{
    "jsonrpc": "2.0",
    "method": "item.get",
    "params": {
      "output": "extend",
      "hostids": "YOUR_HOST_ID",
      "search": {
        "name": "Interface enp86s0: Bits received"
      }
    },
    "auth": "YOUR_AUTH_TOKEN",
    "id": 1
  }'
```

或透過 Zabbix Web UI：
1. 登入 Zabbix Web UI: http://100.64.0.113:8080
2. 導航至: Configuration > Hosts > GC-aro12-agent > Items
3. 搜尋 Item: "Interface enp86s0: Bits received"

#### 步驟 2：如果 Item 不存在，創建 Item

**Item 配置**：
- **Name**: `Interface enp86s0: Bits received`
- **Type**: `Zabbix agent`
- **Key**: `net.if.in["enp86s0"]`
- **Type of information**: `Numeric (unsigned)`
- **Units**: `bps`
- **Update interval**: `30s`
- **History storage period**: `7d`
- **Trend storage period**: `365d`

**Preprocessing**：
1. **Step 1**: Change per second (type: `1`)
   - 計算每秒變化量
2. **Step 2**: Multiply (type: `6`), params: `8`
   - 將 bytes per second 轉換為 bits per second

#### 步驟 3：如果 Item 存在但配置錯誤，更新 Item

**需要檢查的配置**：

1. **Key 是否正確**：
   - 應該是 `net.if.in["enp86s0"]`
   - 不是 `net.if.in[enp86s0]`（缺少引號）
   - 不是 `net.if.in["eth0"]`

2. **Preprocessing 是否正確**：
   - 必須有 "Change per second" preprocessing
   - 必須有 "Multiply by 8" preprocessing
   - 順序必須正確（先 Change per second，再 Multiply）

3. **Units 是否正確**：
   - 應該設置為 `bps` (bits per second)
   - 不是 `B` (bytes) 或 `Bps` (bytes per second)

4. **Item 是否啟用**：
   - Status 應該是 "Enabled"
   - 不是 "Disabled"

#### 步驟 4：驗證 Item 數據

在 Zabbix Server 端執行：

```bash
# 測試 Item 是否可以查詢
zabbix_get -s 100.64.0.149 -k "net.if.in[\"enp86s0\"]"
```

預期結果：應該返回累計 bytes 值（例如：`24533092094`）

#### 步驟 5：檢查 Item 的歷史數據

在 Zabbix Web UI：
1. 導航至: Monitoring > Latest data
2. 選擇 Host: `GC-aro12-agent`
3. 找到 Item: "Interface enp86s0: Bits received"
4. 檢查是否有數據點
5. 檢查數據值是否在合理範圍內（約 6-7 Mbps = 6,000,000-7,000,000 bps）

## 驗證步驟

### 1. 在 Zabbix Web UI 中驗證

1. 登入 Zabbix Web UI: http://100.64.0.113:8080
2. 導航至: Monitoring > Latest data
3. 選擇 Host: `GC-aro12-agent`
4. 確認 Item "Interface enp86s0: Bits received" 有數據
5. 確認數據值在合理範圍內（約 6-7 Mbps）

### 2. 在 Grafana Dashboard 中驗證

1. 登入 Grafana: http://100.64.0.113:3000
2. 開啟 Dashboard: "System Overview"
3. 找到 Panel: "AIPC Network Traffic - All Agents (MBps)"
4. 確認 ARO12 的數據線出現
5. 確認數據值與其他 agents 一致（約 6-7 Mb/s）

## 預期結果

修復完成後，應該看到：

- ✅ Zabbix Server 端 Item "Interface enp86s0: Bits received" 存在且啟用
- ✅ Item 的 key 正確：`net.if.in["enp86s0"]`
- ✅ Item 的 preprocessing 正確配置（Change per second + Multiply by 8）
- ✅ Item 的 units 設置為 `bps`
- ✅ Grafana dashboard 中 ARO12 的網路流量數據正常顯示
- ✅ 數據值與其他 agents 一致（約 6-7 Mb/s）

## 相關檔案

- `zabbix/scripts/network_monitor.sh` - Agent 端腳本（已修復）
- `docker-compose-GC-aro12-agent.yml` - Agent Docker Compose 配置（已修復）
- `grafana/provisioning/dashboards/general/overview.json` - Grafana dashboard 配置（正確）

## 注意事項

1. **如果 Item 已存在但配置錯誤**：
   - 更新 Item 配置後，可能需要等待幾分鐘讓數據更新
   - 或者可以手動觸發一次數據收集

2. **如果使用 Zabbix Template**：
   - 檢查是否有 Template 自動創建 Item
   - 如果有，可能需要更新 Template 配置
   - 或者手動創建 Item 並禁用 Template 的自動創建

3. **與其他 Agents 的一致性**：
   - 確保 ARO12 的 Item 配置與其他正常工作的 agents (ARO11, ARO21, ARO22, ASB11) 一致
   - 特別是 preprocessing 和 units 配置

