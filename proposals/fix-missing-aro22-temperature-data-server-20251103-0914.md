# Fix: Missing ARO22 Temperature Data in AI PC - Temperature Panel

## 背景與錯誤描述

**問題 Panel：** `AI PC - Temperature`  
**影響範圍：** Grafana dashboard 中無法顯示 `GC-ARO-002-2-agent` (ARO22) 的溫度數據

### 問題狀態

從 Grafana dashboard 可見：
- ✅ ARO11, ARO12, ARO21, ASB11 的溫度數據正常顯示
- ❌ ARO22 (GC-ARO-002-2-agent) 的溫度數據無法找到

**Grafana 查詢配置：**
- Query D: `system_temperature_celsius{instance="GC-ARO-002-2-agent"}`
- Legend Format: `ARO22`

### 關鍵觀察

1. **Dashboard 配置正確：**
   - Grafana dashboard 中已正確定義 Query D，查詢 `system_temperature_celsius{instance="GC-ARO-002-2-agent"}`
   - 其他 agents (ARO11, ARO12, ARO21, ASB11) 的查詢都正常運作

2. **數據收集架構：**
   - Zabbix agents 使用 `system.temperature` UserParameter 收集溫度（通過 `system_monitor.sh temperature`）
   - 溫度數據需要透過某種方式轉換為 Prometheus metric `system_temperature_celsius`
   - Prometheus 從 Pushgateway 抓取數據（`job: pushgateway`）
   - 需要確認是否有 server-side 腳本從 Zabbix 收集數據並推送到 Pushgateway

3. **可能的問題：**
   - Agent-side：GC-ARO-002-2-agent 的溫度收集失敗或服務未運行
   - Server-side：收集腳本未包含 GC-ARO-002-2-agent，或推送失敗

## 影響範圍與根因推測

### 可能原因（依優先順序）

1. **Agent-side：溫度收集失敗**
   - `system_monitor.sh temperature` 腳本在 GC-ARO-002-2-agent 上無法正常執行
   - 硬體感測器不存在或無法存取
   - Zabbix agent 容器無法存取宿主機的溫度感測器

2. **Agent-side：服務未運行**
   - Zabbix agent 容器未運行或無法連接
   - Agent 無法與 Zabbix server 通訊

3. **Server-side：收集腳本未包含該 agent**
   - Server-side 可能有定期腳本從 Zabbix API 收集溫度數據並推送到 Pushgateway
   - 腳本可能未包含 `GC-ARO-002-2-agent` 的配置
   - 或腳本執行時該 agent 無法被查詢到

4. **Server-side：Prometheus 抓取問題**
   - Pushgateway 中沒有 GC-ARO-002-2-agent 的數據
   - Prometheus 配置問題，無法正確抓取 Pushgateway 的數據

## 建議修改檔案與重點程式片段

### 步驟 1：檢查 Agent-side 狀態

在 `GC-ARO-002-2-agent` 主機上執行：

```bash
# 檢查 Zabbix agent 容器是否運行
docker ps | grep GC-aro22-agent

# 檢查溫度腳本是否可以正常執行
docker exec telemetry-zabbix-agent-GC-aro22-agent /var/lib/zabbix/scripts/system_monitor.sh temperature

# 檢查 Zabbix agent 日誌
docker logs telemetry-zabbix-agent-GC-aro22-agent --tail 50

# 測試 Zabbix agent 連線
docker exec telemetry-zabbix-agent-GC-aro22-agent zabbix_agent2 -t system.temperature
```

### 步驟 2：檢查 Zabbix Server-side

在 server-side 檢查：

```bash
# 檢查 Zabbix server 是否能看到該 agent
docker exec kevin-telemetry-zabbix-server zabbix_get \
  -s 100.64.0.144 \
  -p 10050 \
  -k "system.temperature"

# 或在 Zabbix Web UI 中檢查：
# Configuration → Hosts → GC-ARO-002-2-agent
# Items → 查看 system.temperature item 的狀態和最新數值
```

### 步驟 3：檢查 Server-side 收集腳本

查找並檢查是否有定期收集溫度數據的腳本：

```bash
# 查找可能的收集腳本
find /home/ella/kevin/telemetry -type f -name "*.sh" -o -name "*.py" -o -name "*.js" | xargs grep -l "system_temperature_celsius\|pushgateway\|agent_temperature"

# 檢查 cron jobs
crontab -l | grep -i "temperature\|pushgateway\|zabbix"
```

### 步驟 4：檢查 Pushgateway 數據

在 server-side 檢查 Pushgateway 中是否有該 agent 的數據：

```bash
# 檢查 Pushgateway 中的 metrics
curl http://localhost:9091/metrics | grep -i "GC-ARO-002-2\|system_temperature_celsius"

# 或在 Prometheus UI 中查詢：
# http://localhost:9090/graph
# 查詢：system_temperature_celsius{instance="GC-ARO-002-2-agent"}
```

### 步驟 5：檢查 Prometheus 配置

確認 Prometheus 配置是否正確抓取 Pushgateway：

```yaml
# prometheus.yml 中應有 pushgateway job：
- job_name: 'pushgateway'
  honor_labels: true
  static_configs:
    - targets: ['pushgateway:9091']
  scrape_interval: 15s
```

## 驗證步驟

1. **在 Zabbix Web UI 中驗證：**
   - Configuration → Hosts → GC-ARO-002-2-agent
   - Items → `system.temperature`
   - 確認狀態為 "Enabled" 且有數值（非 "Not supported"）

2. **在 Agent-side 驗證：**
   ```bash
   docker exec telemetry-zabbix-agent-GC-aro22-agent /var/lib/zabbix/scripts/system_monitor.sh temperature
   # 應該返回溫度數值（攝氏度）
   ```

3. **在 Pushgateway 中驗證：**
   ```bash
   curl http://localhost:9091/metrics | grep "system_temperature_celsius.*GC-ARO-002-2-agent"
   # 應該返回包含該 metric 的行
   ```

4. **在 Prometheus 中驗詢：**
   - Prometheus UI: http://localhost:9090/graph
   - 查詢：`system_temperature_celsius{instance="GC-ARO-002-2-agent"}`
   - 應該返回時間序列數據

5. **在 Grafana 中驗證：**
   - AI PC - Temperature panel 應顯示 ARO22 的溫度曲線
   - 圖例中應有 "ARO22" 標籤

## 風險與回滾方案

### 風險評估

- **低風險**：檢查狀態、查看日誌、測試腳本執行
- **中風險**：修改收集腳本、調整 Prometheus 配置
- **無高風險操作**

### 回滾方案

1. **如果修改腳本導致問題：**
   - 恢復腳本到修改前的狀態
   - 重新啟動服務

2. **如果修改 Prometheus 配置導致問題：**
   - 恢復 `prometheus.yml` 到修改前的狀態
   - 重啟 Prometheus 容器

## 相關檔案

- `/home/ella/kevin/telemetry/zabbix/agent2-GC-ARO-002-2-agent.conf` - Agent 端配置
- `/home/ella/kevin/telemetry/zabbix/scripts/system_monitor.sh` - 溫度收集腳本
- `/home/ella/kevin/telemetry/docker-compose-GC-ARO-002-2-agent.yml` - Agent Docker 配置
- `/home/ella/kevin/telemetry/prometheus.yml` - Prometheus 配置
- `/home/ella/kevin/telemetry/docker-compose.yml` - Server-side Docker 配置

## 預期結果

修復後，應該能夠：
- ✅ 在 Zabbix Web UI 中看到 GC-ARO-002-2-agent 的 `system.temperature` item 有數值
- ✅ 在 Pushgateway 中看到 `system_temperature_celsius{instance="GC-ARO-002-2-agent"}` metric
- ✅ 在 Prometheus 中可以查詢到該 metric
- ✅ 在 Grafana "AI PC - Temperature" panel 中顯示 ARO22 的溫度曲線

## 注意事項

1. **數據收集流程：**
   - Agents 使用 Zabbix 收集溫度數據（`system.temperature`）
   - Server-side 可能有腳本定期從 Zabbix API 收集並推送到 Pushgateway
   - Prometheus 從 Pushgateway 抓取數據
   - Grafana 從 Prometheus 查詢數據

2. **需要確認的關鍵點：**
   - Server-side 是否有收集腳本？如果有，是否包含 GC-ARO-002-2-agent？
   - 如果沒有收集腳本，數據是如何從 Zabbix 轉換為 Prometheus metrics 的？

3. **Agent-side 檢查重點：**
   - 確認 `system_monitor.sh temperature` 腳本可以在該主機上正常執行
   - 確認溫度感測器可存取
   - 確認 Zabbix agent 容器可以存取宿主機的系統資源

## 修復優先順序

**建議先檢查 Agent-side：**
1. 確認 GC-ARO-002-2-agent 的 Zabbix agent 是否正常運行
2. 確認溫度腳本是否可以正常執行
3. 確認 Zabbix server 可以查詢到該 agent 的溫度數據

**然後檢查 Server-side：**
4. 確認 Pushgateway 中是否有該 agent 的數據
5. 確認是否有收集腳本，以及腳本是否包含該 agent
6. 確認 Prometheus 可以從 Pushgateway 抓取到數據

## 修復狀態

**✅ 已修復（2025-11-03）：**

1. **Agent-side 檢查結果：**
   - ✅ Zabbix agent 容器運行正常
   - ✅ 溫度腳本可以正常執行，返回 40°C
   - ✅ Server 端可以透過 `zabbix_get` 查詢到溫度數據

2. **Server-side 修復：**
   - ✅ 建立收集腳本：`scripts/push_agent_temperature_to_pushgateway.sh`
   - ✅ 腳本收集所有 agents（包含 GC-ARO-002-2-agent）的溫度數據
   - ✅ 腳本推送數據到 Pushgateway 作為 `system_temperature_celsius` metric
   - ✅ 設置 cron job（每分鐘執行一次）定期收集溫度數據

3. **驗證結果：**
   - ✅ Pushgateway 中已有所有 agents 的溫度數據：
     - `system_temperature_celsius{instance="GC-ARO-001-1-agent",job="agent_temperature"}`
     - `system_temperature_celsius{instance="GC-aro12-agent",job="agent_temperature"}`
     - `system_temperature_celsius{instance="GC-ARO-002-1-agent",job="agent_temperature"}`
     - `system_temperature_celsius{instance="GC-ARO-002-2-agent",job="agent_temperature"}` ✅
     - `system_temperature_celsius{instance="GC-ASB-001-1-agent",job="agent_temperature"}`

4. **相關檔案：**
   - `/home/ella/kevin/telemetry/scripts/push_agent_temperature_to_pushgateway.sh` - 收集腳本
   - Cron job: `*/1 * * * * /home/ella/kevin/telemetry/scripts/push_agent_temperature_to_pushgateway.sh >> /tmp/push_temperature.log 2>&1`

