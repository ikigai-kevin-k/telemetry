# Grafana Dashboard 查詢操作指南 - AIPC Network Traffic

本指南說明如何在 Grafana 中查詢和驗證 ARO-002-1 agent 的 AIPC Network Traffic 資料。

## 一、登入 Grafana

### 1.1 開啟 Grafana Web UI

**URL**: http://100.64.0.113:3000

**預設登入資訊**:
- 使用者名稱: `admin`
- 密碼: `admin` (首次登入後會要求修改)

### 1.2 登入步驟

1. 在瀏覽器中開啟 http://100.64.0.113:3000
2. 輸入使用者名稱和密碼
3. 點擊 "Log in" 按鈕

---

## 二、查詢 AIPC Network Traffic 資料

### 方法 1: 使用 Overview Dashboard（推薦）

#### 2.1 開啟 Dashboard

1. 在左側選單中，點擊 **Dashboards** (📊)
2. 選擇 **Browse** 或直接搜尋 "Overview"
3. 開啟 **"System Overview"** 或 **"Overview"** dashboard

#### 2.2 找到 Network Traffic Panel

在 dashboard 中找到標題為 **"Network Traffic - All Agents (MBps)"** 的圖表面板。

#### 2.3 查看 ARO-002-1 Agent 資料

**ARO-002-1 Agent 在 dashboard 中顯示為**:
- **ARO21** (別名，在圖例中顯示)
- **GC-ARO-002-1-agent** (完整主機名稱，在查詢中使用)

**預期結果**:
- 圖表中應該顯示一條**黃色線**（ARO21）
- 資料值約在 **6-7 Mb/s** 範圍
- 資料時間應該包含當前時間
- 如果資料正常，線條應該是連續的，不會中斷

**注意**: 
- GC-ARO-002-1-agent 對應的別名是 **ARO21**，不是 ARO12
- ARO12 對應的是 GC-aro12-agent（不同的 agent）

#### 2.4 驗證資料更新

1. 點擊右上角的 **時間選擇器** (例如 "Last 6 hours")
2. 選擇 **"Last 1 hour"** 或 **"Last 15 minutes"**
3. 點擊 **重新整理按鈕** (🔄) 或按 `Ctrl+R` 重新整理
4. 確認資料線是否持續更新到最新時間

---

### 方法 2: 使用 Master Agents Monitoring Dashboard

#### 2.1 開啟 Dashboard

1. 在左側選單中，點擊 **Dashboards** (📊)
2. 選擇 **Browse**
3. 開啟 **"Master Agents Monitoring"** dashboard

#### 2.2 找到 Network Traffic Panel

在 dashboard 中找到標題為 **"Network Traffic - All Agents"** 的圖表面板。

#### 2.3 查看 ARO-002-1 Agent 資料

**查詢配置**:
- **Host**: `GC-ARO-002-1-agent`
- **Item**: `net.if.in["eth0"]` 或 `Interface eth0: Bits received` (接收流量)
- **Item**: `net.if.out["eth0"]` 或 `Interface eth0: Bits sent` (發送流量)

**預期結果**:
- 圖表中應該顯示 ARO21 的網路流量資料（別名）
- 包含接收 (RX) 和發送 (TX) 兩條線
- 資料值應該持續更新

**注意**: 
- 查詢時使用 Host: **GC-ARO-002-1-agent**（注意大小寫和連字號）
- 在圖例中顯示為 **ARO21**

---

## 三、使用 Grafana Explore 進行進階查詢

### 3.1 開啟 Explore

1. 在左側選單中，點擊 **Explore** (🔍) 圖示
2. 或使用快捷鍵 `Ctrl+E`

### 3.2 選擇 Data Source

在右上角選擇 **Zabbix** data source。

### 3.3 查詢 ARO-002-1 Agent 網路流量

#### 查詢 1: 接收流量 (RX)

**查詢配置**:
```
Group: Linux servers
Host: GC-ARO-002-1-agent
Item: Interface eth0: Bits received
```

或使用 Item Key:
```
Group: Linux servers
Host: GC-ARO-002-1-agent
Item: net.if.in["eth0"]
```

#### 查詢 2: 發送流量 (TX)

**查詢配置**:
```
Group: Linux servers
Host: GC-ARO-002-1-agent
Item: Interface eth0: Bits sent
```

或使用 Item Key:
```
Group: Linux servers
Host: GC-ARO-002-1-agent
Item: net.if.out["eth0"]
```

**注意**: 
- Host 名稱必須是 **GC-ARO-002-1-agent**（注意大小寫：ARO 全大寫，002-1 有連字號）
- 在圖例中會顯示為 **ARO21**

### 3.4 執行查詢

1. 點擊 **"Run query"** 按鈕
2. 選擇時間範圍（例如：Last 1 hour）
3. 查看查詢結果

**預期結果**:
- 查詢應該返回時間序列資料
- 圖表應該顯示網路流量曲線
- 資料值應該在合理範圍內（約 6-7 Mb/s）

---

## 四、驗證資料是否正常

### 4.1 檢查資料時間

1. 查看圖表右下角的**最後資料點時間**
2. 確認時間是否為**當前時間**（或幾分鐘內）
3. 如果資料時間過舊（超過 10 分鐘），可能表示資料沒有正常推送

### 4.2 檢查資料值

**正常範圍**:
- **接收流量 (RX)**: 約 6-7 Mb/s
- **發送流量 (TX)**: 約 6-7 Mb/s

**異常情況**:
- 資料值為 **0** 或接近 0 → Agent 可能沒有正常運作
- 資料線**中斷** → 可能在某個時間點停止推送
- 資料值**異常高或低** → 可能有網路問題

### 4.3 檢查資料線連續性

1. 選擇較長的時間範圍（例如：Last 6 hours）
2. 查看資料線是否連續
3. 如果資料線在特定時間點**突然中斷**，可能表示：
   - Agent 在那個時間點重啟或停止
   - 網路連線中斷
   - Zabbix Server 無法連接到 Agent

---

## 五、故障排除

### 問題 1: Dashboard 顯示 "No data"

**可能原因**:
- Agent 沒有正常啟動
- Zabbix Server 無法連接到 Agent
- 查詢條件不正確

**解決步驟**:
1. 檢查 Agent 容器狀態：
   ```bash
   docker ps | grep aro21-agent
   ```

2. 檢查 Zabbix Agent 連線：
   ```bash
   docker logs telemetry-zabbix-agent-GC-aro21-agent | tail -50
   ```

3. 在 Grafana Explore 中測試查詢：
   - 使用不同的 Item 名稱
   - 確認 Host 名稱正確（GC-ARO-002-1-agent，注意大小寫）

### 問題 2: 資料時間過舊

**可能原因**:
- Agent 停止推送資料
- Zabbix Server 無法從 Agent 取得資料

**解決步驟**:
1. 檢查 Zabbix Server 中的 Host 狀態：
   - 登入 http://100.64.0.113:8080
   - 檢查 Configuration > Hosts > GC-ARO-002-1-agent
   - 確認 Agent 狀態為 "Available"

2. 重啟 Agent：
   ```bash
   sudo systemctl restart telemetry-aro-002-1-agent.service
   ```

### 問題 3: 資料值為 0

**可能原因**:
- 網路介面名稱不正確
- Agent 無法讀取網路統計資料

**解決步驟**:
1. 檢查實際使用的網路介面：
   ```bash
   docker exec telemetry-zabbix-agent-GC-aro21-agent cat /proc/net/dev
   ```

2. 測試不同的介面名稱：
   - 在 Explore 中嘗試查詢 `enp86s0` 介面
   - 或查詢 `eth0` 介面

### 問題 4: 資料線在特定時間中斷

**可能原因**:
- Agent 在那個時間點重啟
- 系統在那個時間點重啟
- 網路連線中斷

**解決步驟**:
1. 檢查系統重啟時間：
   ```bash
   uptime
   last reboot
   ```

2. 檢查 Agent 容器重啟時間：
   ```bash
   docker ps -a | grep aro21-agent
   ```

3. 檢查 systemd service 日誌：
   ```bash
   sudo journalctl -u telemetry-aro-002-1-agent.service --since "1 hour ago"
   ```

---

## 六、快速查詢指令參考

### 在 Grafana Explore 中的查詢配置

#### 查詢 ARO-002-1 Agent 接收流量
```
Data Source: Zabbix
Group: Linux servers
Host: GC-ARO-002-1-agent
Item: Interface eth0: Bits received
```

#### 查詢 ARO-002-1 Agent 發送流量
```
Data Source: Zabbix
Group: Linux servers
Host: GC-ARO-002-1-agent
Item: Interface eth0: Bits sent
```

**重要**: Host 名稱是 **GC-ARO-002-1-agent**（不是 GC-aro12-agent），在圖例中顯示為 **ARO21**

#### 查詢所有 Agents 的網路流量（比較）
```
Data Source: Zabbix
Group: Linux servers
Host: GC-aro11-agent, GC-aro12-agent, GC-ARO-002-1-agent, GC-aro22-agent, GC-asb11-agent
Item: net.if.in["eth0"]
```

**注意**: GC-ARO-002-1-agent 在圖例中顯示為 ARO21

---

## 七、Dashboard 位置參考

### 主要 Dashboards

1. **System Overview** / **Overview**
   - 路徑: Dashboards > Browse > Overview
   - Panel: "Network Traffic - All Agents (MBps)"
   - 顯示所有 Agents 的網路流量（包含 ARO21，對應 GC-ARO-002-1-agent）

2. **Master Agents Monitoring**
   - 路徑: Dashboards > Browse > Master Agents Monitoring
   - Panel: "Network Traffic - All Agents"
   - 詳細的 Agents 監控資訊

### 相關 Dashboards

- **Zabbix System Monitoring** (個別 Agent 詳細監控)
- **Network Monitor enp86s0** (Loki 資料來源的網路監控)

---

## 八、驗證檢查清單

在確認 ARO-002-1 Agent 資料正常推送後，請檢查以下項目：

- [ ] Grafana Dashboard 中可以看到 ARO21 的資料線（對應 GC-ARO-002-1-agent）
- [ ] 資料時間為當前時間（或幾分鐘內）
- [ ] 資料值在合理範圍內（約 6-7 Mb/s）
- [ ] 資料線連續，沒有中斷
- [ ] 可以查詢到接收 (RX) 和發送 (TX) 流量
- [ ] 在 Zabbix Server 中 Host 狀態為 "Available"
- [ ] Agent 容器正常運行

---

## 九、常用操作快捷鍵

- `Ctrl+E`: 開啟 Explore
- `Ctrl+R`: 重新整理 Dashboard
- `Ctrl+F`: 搜尋 Dashboard
- `Ctrl+K`: 開啟命令面板

---

## 十、聯絡資訊

如果遇到問題無法解決，請檢查：

1. **Agent 端日誌**:
   ```bash
   docker logs telemetry-zabbix-agent-GC-aro21-agent
   docker logs telemetry-promtail-GC-aro21-agent
   ```

2. **Systemd Service 日誌**:
   ```bash
   sudo journalctl -u telemetry-aro-002-1-agent.service -f
   ```

3. **Zabbix Server 狀態**:
   - 登入 http://100.64.0.113:8080
   - 檢查 Host 配置和狀態

---

**最後更新**: 2025-11-28  
**適用版本**: Grafana 9.5.21, Zabbix Agent 2

