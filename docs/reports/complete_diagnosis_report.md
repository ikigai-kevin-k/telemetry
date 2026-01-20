# GC-ARO-001-1 Agent Network Monitoring 完整診斷報告

## 📋 診斷概要

**診斷時間**: 2025-10-22 06:48 - 07:26 (UTC+4)  
**問題描述**: Grafana Explore 中查詢 `{job="network_monitor"}` 顯示 "No logs found"  
**目標**: 確保 Server-side Loki 能接收來自 aro-001-1 agent 的 enp86s0 metrics  
**診斷範圍**: Server-side 配置修正 + Agent-side 狀態確認 + 資料傳輸驗證  

## 🔧 系統配置資訊

### 網路配置
- **Server IP**: 100.64.0.113
- **Agent IP**: 100.64.0.167
- **Loki Port**: 3100
- **Grafana Port**: 3000

### Agent 標籤配置
- **Agent Instance**: GC-aro12-agent (修正後)
- **Job**: network_monitor
- **Interface**: enp86s0

## 🔍 診斷階段與結果

### 階段 1: 初始問題診斷 (06:48-06:53)

#### 問題發現
- **Grafana Explore**: 查詢 `{job="network_monitor"}` 返回 "No logs found"
- **Loki 查詢**: 所有 network monitoring 相關查詢返回空結果
- **標籤存在**: `network_monitor`, `enp86s0`, `GC-aro12-agent` 標籤都存在

#### 根本原因識別
**標籤匹配問題**: Server-side 配置使用 `GC-aro11-agent`，但 Agent-side 實際使用 `GC-aro12-agent`

### 階段 2: Server-side 配置修正 (06:53-06:57)

#### 修正內容
1. **Promtail 配置修正** (`promtail-GC-ARO-001-1-agent.yml`)
   ```yaml
   # 修正前
   instance: GC-aro11-agent
   
   # 修正後  
   instance: GC-aro12-agent  # Match agent-side instance label
   ```

2. **Docker Compose 配置確認** (`docker-compose-GC-ARO-001-1-agent.yml`)
   ```yaml
   # 確認 volume mount 存在
   - /var/log/network_stats.log:/var/log/network_stats.log:ro
   ```

3. **保持現有配置不變**
   - 所有 SDP log 配置保持原樣
   - 只新增 network monitoring 配置

#### 修正驗證
- ✅ Promtail 配置語法正確
- ✅ Docker Compose 配置驗證通過
- ✅ 標籤匹配問題已解決

### 階段 3: Agent-side 狀態確認 (07:14-07:17)

#### Agent-side 診斷結果
根據 Agent-side 修正報告：

| 項目 | 狀態 | 詳細說明 |
|------|------|----------|
| Promtail 容器 | ✅ 正常 | 容器運行中，配置已更新 |
| Network Monitoring 腳本 | ✅ 正常 | Python 腳本運行中 (PID: 3436595) |
| Log 檔案 | ✅ 正常 | network_stats.log 持續更新，每10秒產生新資料 |
| 資料解析 | ✅ 正常 | JSON 解析成功，標籤正確 |
| Loki 連線 | ✅ 正常 | 服務器回應 "ready" |

#### Agent-side 修正行動
1. **增加 Debug 日誌級別**
   ```yaml
   server:
     log_level: debug
   ```

2. **優化客戶端批次設定**
   ```yaml
   clients:
     - url: http://100.64.0.113:3100/loki/api/v1/push
       batchwait: 1s
       batchsize: 1     # 立即發送
       timeout: 10s
   ```

3. **重新啟動 Promtail 容器**
   ```bash
   docker compose -f docker-compose.agent.yml restart promtail
   ```

### 階段 4: Server-side 資料接收確認 (07:26)

#### 確認結果
**❌ Server-side Loki 尚未收到 enp86s0 metrics**

| 檢查項目 | 狀態 | 說明 |
|----------|------|------|
| Loki 服務狀態 | ✅ 正常 | 容器運行中，端口正常 |
| Network Monitor 資料 (過去 10 分鐘) | ❌ 未收到 | 查詢 `{job="network_monitor"}` 返回空結果 |
| GC-aro12-agent 資料 (過去 10 分鐘) | ❌ 未收到 | 查詢 `{instance="GC-aro12-agent"}` 返回空結果 |
| enp86s0 介面資料 (過去 10 分鐘) | ❌ 未收到 | 查詢 `{job="network_monitor", interface="enp86s0"}` 返回空結果 |
| 完整查詢 (過去 10 分鐘) | ❌ 未收到 | 查詢 `{job="network_monitor", instance="GC-aro12-agent", interface="enp86s0"}` 返回空結果 |
| JSON 解析 (過去 10 分鐘) | ❌ 失敗 | 查詢 `{job="network_monitor", instance="GC-aro12-agent"} \| json` 返回空結果 |
| 過去 30 分鐘資料 | ❌ 未收到 | 查詢返回空結果 |
| 過去 1 小時資料 | ❌ 未收到 | 查詢返回空結果 |

#### Loki 日誌分析
從 Loki 日誌中可以看到：
- 所有查詢都返回 `returned_lines=0`
- 查詢執行正常，但沒有返回任何資料
- 沒有錯誤訊息，表示查詢語法正確
- 沒有看到任何資料接收記錄

## 🎯 問題分析

### 已解決的問題
1. **✅ 標籤匹配問題** - Server-side 和 Agent-side 都使用 `GC-aro12-agent`
2. **✅ 配置語法問題** - 所有配置檔案語法正確
3. **✅ 服務運行問題** - Loki 和 Promtail 服務都正常運行
4. **✅ 資料收集問題** - Agent-side 正在成功收集和處理資料

### 待解決的問題
**❌ 資料傳輸問題** - Agent-side 正在處理資料但沒有成功發送到 Server-side Loki

## 🔍 根本原因分析

### 可能原因
1. **網路連線問題**
   - Agent-side 無法連接到 Server-side Loki
   - 防火牆阻擋連線
   - 網路延遲或丟包

2. **Promtail 客戶端問題**
   - 批次設定問題 (已設定為 `batchsize: 1`)
   - 超時設定問題
   - 認證或授權問題

3. **Loki 接收問題**
   - Loki 配置問題
   - 儲存空間問題
   - 權限問題

4. **時間同步問題**
   - Agent-side 和 Server-side 時間不同步
   - 時區設定問題

## 🛠️ 解決方案建議

### 優先級 1: 網路連線檢查
```bash
# 從 Agent-side 測試連線
curl -v http://100.64.0.113:3100/ready

# 測試 Loki API
curl -v -G "http://100.64.0.113:3100/loki/api/v1/label/__name__/values"
```

### 優先級 2: Promtail 除錯
```bash
# 檢查 Promtail 日誌中的錯誤
docker logs <promtail_container_name> --tail 100 | grep -E "(error|warn|fail)"

# 檢查 Promtail 配置
cat promtail-config.yml | grep -A 10 -B 5 "100.64.0.113"
```

### 優先級 3: Loki 接收檢查
```bash
# 檢查 Loki 接收日誌
docker logs kevin-telemetry-loki-server --tail 100 | grep -E "(ingest|push|receive)"

# 檢查 Loki 配置
cat loki-config.yml | grep -A 5 -B 5 "ingestion"
```

### 優先級 4: 手動測試資料傳輸
```bash
# 使用 logcli 手動推送測試資料
echo '{"timestamp":"2025-10-22 07:30:00","interface":"enp86s0","rx_bytes":1000,"tx_bytes":2000}' | \
logcli --addr=http://100.64.0.113:3100 push --labels='{job="network_monitor",instance="GC-aro12-agent",interface="enp86s0"}'
```

## 📊 技術摘要

### 配置狀態
| 項目 | Agent-side | Server-side | 狀態 |
|------|------------|-------------|------|
| 服務運行 | ✅ 正常 | ✅ 正常 | 正常 |
| 配置修正 | ✅ 完成 | ✅ 完成 | 完成 |
| 標籤匹配 | ✅ 正確 | ✅ 正確 | 完成 |
| 資料收集 | ✅ 正常 | ❌ 未收到 | 問題 |
| 資料處理 | ✅ 正常 | ❌ 未收到 | 問題 |
| 資料傳輸 | ❌ 失敗 | ❌ 未收到 | 問題 |

### 修正摘要
- **修正檔案**: `promtail-GC-ARO-001-1-agent.yml`
- **修正標籤**: `instance: GC-aro12-agent`
- **保持配置**: 所有現有的 SDP log 配置
- **新增配置**: 專門的 network monitoring job

## 🎯 Grafana Explore 查詢指南

### 推薦查詢順序
在 Grafana Explore 中依序嘗試以下查詢：

1. **基本查詢**
   ```
   {job="network_monitor"}
   ```

2. **加上 instance 標籤**
   ```
   {job="network_monitor", instance="GC-aro12-agent"}
   ```

3. **完整的 aro-001-1 enp86s0 查詢**
   ```
   {job="network_monitor", instance="GC-aro12-agent", interface="enp86s0"}
   ```

4. **JSON 解析查詢**
   ```
   {job="network_monitor", instance="GC-aro12-agent"} | json
   ```

5. **過濾有效資料**
   ```
   {job="network_monitor", instance="GC-aro12-agent"} | json | __error__=""
   ```

### 查詢參數設定
- **時間範圍**: 選擇 "Last 6 hours" 或 "Last 24 hours"
- **查詢限制**: 設定為 1000
- **資料來源**: 確認選擇 "Loki"
- **視圖模式**: 選擇 "Logs" 查看原始資料

### 成功指標
當以下條件滿足時，表示問題已解決：
- ✅ Grafana Explore 查詢返回 log 資料
- ✅ JSON 解析成功
- ✅ 可以看到 rx_bits, tx_bits 等欄位
- ✅ 時間戳記正確
- ✅ 資料持續更新

## 📋 除錯技巧

### 查詢技巧
1. **使用標籤過濾器**: `{job="network_monitor"}`
2. **組合多個標籤**: `{job="network_monitor", instance="GC-aro12-agent"}`
3. **使用管道操作符**: `| json | rx_bits > 0`
4. **使用正則表達式**: `{job=~".*network.*"}`

### 除錯技巧
1. **先查詢基本標籤**: `{job="network_monitor"}`
2. **逐步縮小範圍**: 加上 instance, interface 標籤
3. **檢查 JSON 解析**: `| json | __error__=""`
4. **查看原始資料**: 不使用管道操作符

### 視覺化技巧
1. **使用 'Logs' 視圖**: 查看原始 log
2. **使用 'Table' 視圖**: 查看結構化資料
3. **使用 'Graph' 視圖**: 查看時間序列資料

## 🔧 快速參考

### 重要 URL
- **Grafana Explore**: http://100.64.0.113:3000/explore
- **Loki API**: http://100.64.0.113:3100
- **Loki Ready Check**: http://100.64.0.113:3100/ready

### 關鍵命令
```bash
# 檢查 Loki 服務狀態
curl -s http://100.64.0.113:3100/ready

# 查詢 network monitoring 資料
curl -s -G "http://100.64.0.113:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={job="network_monitor"}' \
  --data-urlencode 'start='$(date -d '10 minutes ago' -u +%Y-%m-%dT%H:%M:%SZ) \
  --data-urlencode 'end='$(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --data-urlencode 'limit=5'

# 檢查 Loki 容器狀態
docker ps | grep loki

# 檢查 Loki 日誌
docker logs kevin-telemetry-loki-server --tail 50
```

## 🎯 下一步行動

### 立即行動
1. **檢查 Agent-side Promtail 日誌** - 尋找錯誤或警告訊息
2. **測試網路連線** - 確認 Agent-side 可以連接到 Server-side
3. **檢查 Loki 接收日誌** - 確認是否有資料接收記錄

### 持續監控
1. **使用 Grafana Explore 持續查詢** - 監控資料是否開始到達
2. **監控 Loki 日誌** - 檢查是否有新的接收記錄
3. **確認資料傳輸恢復** - 一旦問題解決，資料應該開始正常傳輸

### 成功標準
- ✅ Grafana Explore 查詢返回資料
- ✅ JSON 解析成功
- ✅ 可以看到 network monitoring 欄位
- ✅ 資料持續更新

## 📋 結論

### 已完成的工作
1. **✅ 成功診斷問題** - 識別標籤匹配問題
2. **✅ 修正 Server-side 配置** - 更新 instance 標籤為 GC-aro12-agent
3. **✅ 確認 Agent-side 狀態** - 所有服務正常運行
4. **✅ 驗證配置正確性** - 語法和邏輯都正確

### 待解決的問題
**❌ 資料傳輸層面** - Agent-side 正在處理資料但沒有成功發送到 Server-side Loki

### 問題定位
**最可能的原因**: 網路連線問題或 Promtail 客戶端配置問題

### 建議優先順序
1. **檢查 Agent-side Promtail 日誌** - 尋找發送失敗的錯誤訊息
2. **測試網路連線** - 確認 Agent-side 可以連接到 Server-side Loki
3. **檢查 Loki 接收配置** - 確認 Server-side 可以接收資料

**所有配置修正都已完成，現在需要專注於資料傳輸層面的問題解決。**

---

**診斷完成時間**: 2025-10-22 07:26:09 AM +04  
**診斷狀態**: 配置修正完成，待解決資料傳輸問題  
**下一步**: 檢查網路連線和 Promtail 客戶端配置



