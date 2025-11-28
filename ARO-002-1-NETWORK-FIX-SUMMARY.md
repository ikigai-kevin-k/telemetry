# ARO-002-1 Agent Network Traffic Fix Summary

**修復日期**: 2025-11-28  
**問題**: Network traffic metrics 顯示異常小（約 3-4 Kbps）  
**根本原因**: Zabbix Agent 讀取的是容器內的虛擬介面 `eth0`，而非主機的實體介面 `enp86s0`

## 問題診斷

### 發現的問題

1. **實際網絡介面**: 主機使用 `enp86s0` 作為實體網絡介面
2. **容器內介面**: Zabbix Agent 容器內看到的 `eth0` 是 Docker 橋接的虛擬介面
3. **流量差異**:
   - `eth0` (容器內): 約 5.7 MB 累計流量
   - `enp86s0` (主機實體): 約 21.7 GB 累計流量
   - 實際流量速率: 約 6.71 Mbps（正常範圍）

### 驗證結果

```bash
# 主機實體介面流量
system.network.in[enp86s0] = 22,217,420,506 bytes ✅

# 新的自定義 key (映射到 enp86s0)
custom.net.if.in.bytes[eth0] = 22,216,580,218 bytes ✅ (正確的大數值)

# 容器虛擬介面流量 (舊的，錯誤的)
net.if.in[eth0] = 10,261 bytes ❌ (太小，這是容器內的虛擬介面)

# 實際流量速率測試
30秒內增加: 25,167,304 bytes
速率: 6,711,281 bps (6.71 Mbps) ✅ 正常
```

## 實施的修復方案

### 方案：使用自定義 UserParameter 映射

由於 Zabbix Agent 內建的 `net.if.in[eth0]` key 無法被 UserParameter 覆蓋，我們使用自定義 key：

**配置檔案**: `zabbix/agent2-GC-ARO-002-1-agent.conf`

```conf
# Network interface monitoring - Map eth0 to enp86s0 for compatibility
# Use custom keys to override built-in net.if.* keys and read from physical interface
# These keys map eth0 requests to the actual enp86s0 physical interface
# Note: When querying with custom.net.if.in.bytes[eth0], it will read enp86s0 statistics
UserParameter=custom.net.if.in.bytes[*],if [ "$1" = "eth0" ]; then /var/lib/zabbix/scripts/system_monitor.sh network_in enp86s0; else /var/lib/zabbix/scripts/system_monitor.sh network_in "$1"; fi
UserParameter=custom.net.if.out.bytes[*],if [ "$1" = "eth0" ]; then /var/lib/zabbix/scripts/system_monitor.sh network_out enp86s0; else /var/lib/zabbix/scripts/system_monitor.sh network_out "$1"; fi
```

### 工作原理

1. **自定義 Key**: `custom.net.if.in.bytes[eth0]` 和 `custom.net.if.out.bytes[eth0]`
2. **映射邏輯**: 當查詢 `eth0` 時，實際讀取 `enp86s0` 的統計資料
3. **資料來源**: 使用已 mount 的 `/host/sys/class/net/enp86s0/statistics/` 路徑

## 後續步驟（Server-side）

### 需要在 Zabbix Server 端執行的操作

1. **更新現有 Items** 或 **創建新 Items**:
   - 將 Item Key 從 `net.if.in[eth0]` 改為 `custom.net.if.in.bytes[eth0]`
   - 將 Item Key 從 `net.if.out[eth0]` 改為 `custom.net.if.out.bytes[eth0]`

2. **Item 配置**:
   - **Type**: Zabbix agent (active)
   - **Key**: `custom.net.if.in.bytes[eth0]` 或 `custom.net.if.out.bytes[eth0]`
   - **Type of information**: Numeric (unsigned)
   - **Units**: `B` (bytes)
   - **Preprocessing**: 
     - Change per second
     - Multiply by 8 (轉換為 bits per second)
   - **Units**: `bps` (最終顯示單位)

3. **更新 Grafana Dashboard**:
   - 修改查詢條件，使用新的 Item Key
   - 或保持 Item 名稱不變（如果 Item 名稱是 "Interface eth0: Bits received"）

### 驗證步驟

1. **在 Agent 端驗證**:
   ```bash
   docker exec telemetry-zabbix-agent-GC-aro21-agent zabbix_agent2 -t "custom.net.if.in.bytes[eth0]"
   docker exec telemetry-zabbix-agent-GC-aro21-agent zabbix_agent2 -t "custom.net.if.out.bytes[eth0]"
   ```
   預期結果：應該返回與 `system.network.in[enp86s0]` 相同的大數值（約 21+ GB）

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

- `zabbix/agent2-GC-ARO-002-1-agent.conf` - Agent 配置（已修改）
- `zabbix/scripts/system_monitor.sh` - 系統監控腳本（使用 `/host/sys` 路徑）
- `docker-compose-GC-ARO-002-1-agent.yml` - Docker Compose 配置（已正確 mount `/sys`）

## 注意事項

1. **同樣的問題可能也存在於 ARO-002-2**:
   - 需要對 `zabbix/agent2-GC-ARO-002-2-agent.conf` 進行相同的修改

2. **Zabbix Server Items 更新**:
   - 必須在 Zabbix Server 端更新或創建新的 Items 才能使用新的 keys
   - 可以使用 Zabbix API 或 Web UI 來更新

3. **資料單位**:
   - 新的 keys 返回的是 bytes（累計值）
   - 需要在 Zabbix Server 端設置 "Change per second" preprocessing
   - 然後乘以 8 轉換為 bits per second

## 預期結果

修復後，ARO-002-1 agent 的網絡流量數據應該：
- ✅ 顯示正常的流量值（約 6-7 Mbps）
- ✅ 與其他 agents (ARO11, ARO12, ASB11) 的數據範圍一致
- ✅ 持續更新，不再出現異常小的數值

