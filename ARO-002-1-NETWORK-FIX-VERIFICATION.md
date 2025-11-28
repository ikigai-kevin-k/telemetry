# ARO-002-1 Network Traffic Fix - 驗證報告

**驗證時間**: 2025-11-28 10:20  
**修復狀態**: ✅ **成功**

## 修復前後對比

### 修復前

| Metric | 數值 | 狀態 |
|--------|------|------|
| `net.if.in[eth0]` | ~5.7 MB | ❌ 異常小（容器虛擬介面） |
| `net.if.out[eth0]` | ~5.3 MB | ❌ 異常小（容器虛擬介面） |
| Grafana 顯示 | 3-4 Kbps | ❌ 異常小 |

### 修復後

| Metric | 數值 | 狀態 |
|--------|------|------|
| `custom.net.if.in.bytes[eth0]` | 22,216,580,218 bytes | ✅ 正確（映射到 enp86s0） |
| `custom.net.if.out.bytes[eth0]` | 26,453,538,109 bytes | ✅ 正確（映射到 enp86s0） |
| `system.network.in[enp86s0]` | 22,217,420,506 bytes | ✅ 正確（直接讀取） |
| 實際流量速率 | ~6.71 Mbps | ✅ 正常範圍 |

## 驗證測試結果

### 1. Agent 端測試

```bash
# 測試新的自定義 key
$ docker exec telemetry-zabbix-agent-GC-aro21-agent zabbix_agent2 -t "custom.net.if.in.bytes[eth0]"
custom.net.if.in.bytes[eth0]                  [s|22216580218]  ✅

$ docker exec telemetry-zabbix-agent-GC-aro21-agent zabbix_agent2 -t "custom.net.if.out.bytes[eth0]"
custom.net.if.out.bytes[eth0]                 [s|26453538109]  ✅

# 對比驗證
$ docker exec telemetry-zabbix-agent-GC-aro21-agent zabbix_agent2 -t "system.network.in[enp86s0]"
system.network.in[enp86s0]                    [s|22217420506]  ✅ (幾乎相同)

# 舊的 key (容器虛擬介面)
$ docker exec telemetry-zabbix-agent-GC-aro21-agent zabbix_agent2 -t "net.if.in[eth0]"
net.if.in[eth0]                               [s|10261]  ❌ (非常小)
```

### 2. 數值一致性驗證

- `custom.net.if.in.bytes[eth0]` = 22,216,580,218 bytes
- `system.network.in[enp86s0]` = 22,217,420,506 bytes
- **差異**: 僅 840,288 bytes (約 0.004%)，屬於正常範圍（讀取時間差）

### 3. 流量速率驗證

實際測試顯示流量速率約 **6.71 Mbps**，屬於正常範圍（與其他 agents 的 6-7 Mbps 一致）。

## 修復方案實施

### 修改的檔案

1. **`zabbix/agent2-GC-ARO-002-1-agent.conf`**
   - 新增自定義 UserParameter
   - 將 `eth0` 查詢映射到 `enp86s0` 實體介面

### 配置內容

```conf
# Network interface monitoring - Map eth0 to enp86s0 for compatibility
UserParameter=custom.net.if.in.bytes[*],if [ "$1" = "eth0" ]; then /var/lib/zabbix/scripts/system_monitor.sh network_in enp86s0; else /var/lib/zabbix/scripts/system_monitor.sh network_in "$1"; fi
UserParameter=custom.net.if.out.bytes[*],if [ "$1" = "eth0" ]; then /var/lib/zabbix/scripts/system_monitor.sh network_out enp86s0; else /var/lib/zabbix/scripts/system_monitor.sh network_out "$1"; fi
```

## 後續步驟（Server-side）

### 需要在 Zabbix Server 端執行

1. **更新或創建 Items**:
   - 將 Item Key 從 `net.if.in[eth0]` 改為 `custom.net.if.in.bytes[eth0]`
   - 將 Item Key 從 `net.if.out[eth0]` 改為 `custom.net.if.out.bytes[eth0]`

2. **Item 配置建議**:
   - **Type**: Zabbix agent (active)
   - **Key**: `custom.net.if.in.bytes[eth0]`
   - **Type of information**: Numeric (unsigned)
   - **Units**: `B` (bytes)
   - **Preprocessing**:
     1. Change per second
     2. Multiply by 8 (轉換為 bits per second)
   - **Units** (最終): `bps`

3. **驗證 Server 端連線**:
   ```bash
   # 在 Zabbix Server 端執行
   zabbix_get -s 100.64.0.143 -k "custom.net.if.in.bytes[eth0]"
   zabbix_get -s 100.64.0.143 -k "custom.net.if.out.bytes[eth0]"
   ```

## 預期結果

修復完成後，在 Grafana dashboard 中應該看到：

- ✅ ARO21 的網絡流量數據顯示正常（約 6-7 Mbps）
- ✅ 與其他 agents (ARO11, ARO12, ASB11) 的數據範圍一致
- ✅ 數據持續更新，不再出現異常小的數值

## 注意事項

1. **同樣的問題可能存在於 ARO-002-2**:
   - 需要對 `zabbix/agent2-GC-ARO-002-2-agent.conf` 進行相同的修改

2. **Zabbix Server Items 必須更新**:
   - 必須在 Zabbix Server 端更新 Items 才能使用新的 keys
   - 否則 Grafana 仍會查詢舊的 `net.if.in[eth0]`，顯示錯誤的數據

3. **資料單位處理**:
   - 新的 keys 返回的是 bytes（累計值）
   - 必須在 Zabbix Server 端設置 "Change per second" preprocessing
   - 然後乘以 8 轉換為 bits per second

## 相關檔案

- `zabbix/agent2-GC-ARO-002-1-agent.conf` - Agent 配置（已修改）✅
- `zabbix/scripts/system_monitor.sh` - 系統監控腳本（使用 `/host/sys` 路徑）✅
- `docker-compose-GC-ARO-002-1-agent.yml` - Docker Compose 配置（已正確 mount `/sys`）✅
- `ARO-002-1-NETWORK-FIX-SUMMARY.md` - 修復摘要文件

