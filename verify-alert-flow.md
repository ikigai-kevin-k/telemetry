# 驗證 Alert 系統流程

## 📊 如何確認系統正在檢測和發送請求

### 1️⃣ 檢查 Alert 是否檢測到 okbps=0,0,0

```bash
# 查看 Grafana alert 評估日誌
docker logs kevin-telemetry-grafana --since 5m 2>&1 | grep "srs-okbps-zero-alert"
```

**應該看到：**
```
logger=ngalert.sender.router rule_uid=srs-okbps-zero-alert org_id=1 
msg="Sending alerts to local notifier" count=23
```

✅ **count=23** 表示檢測到 23 個符合條件的警報（okbps=0,0,0）

---

### 2️⃣ 確認 Webhook 服務收到請求

```bash
# 實時查看 webhook 服務日誌
tail -f /home/ella/kevin/telemetry/webhook_service.log
```

**應該看到：**
```
2025-10-01 16:00:15 - __main__ - INFO - Received Grafana alert: {
  "status": "firing",
  "alerts": [...]
}
2025-10-01 16:00:15 - __main__ - INFO - Alert status: firing
2025-10-01 16:00:15 - __main__ - INFO - Processing alert: SRSNoDataAlert
```

---

### 3️⃣ 確認 API 請求已發送

在 webhook 服務日誌中查找：

```bash
grep "Sending API request" /home/ella/kevin/telemetry/webhook_service.log
grep "API Response" /home/ella/kevin/telemetry/webhook_service.log
```

**應該看到：**
```
2025-10-01 16:00:15 - __main__ - INFO - Sending API request to http://100.64.0.160:8085/v1/service/status
2025-10-01 16:00:15 - __main__ - INFO - Payload: {
  "tableId": "ARO-001",
  "zCam": "down"
}
2025-10-01 16:00:15 - __main__ - INFO - API Response Status: 200
2025-10-01 16:00:15 - __main__ - INFO - API Response Body: {...}
```

---

## 🧪 當前系統狀態檢查

### 檢查 1: Loki 中是否有 okbps=0,0,0 日誌

```bash
# 查詢最近 3 小時的 okbps=0,0,0 日誌數量
curl -s -G 'http://100.64.0.160:3100/loki/api/v1/query_range' \
  --data-urlencode 'query={job="srs_test"} |= "okbps=0,0,0"' \
  --data-urlencode "start=$(date -d '3 hours ago' +%s)000000000" \
  --data-urlencode "end=$(date +%s)000000000" \
  --data-urlencode 'limit=10' | python3 -m json.tool
```

### 檢查 2: Grafana Alert Rule 狀態

訪問 Grafana UI:
1. 打開 `http://100.64.0.160:3000`
2. 登入 (admin/admin)
3. 導航到 **Alerting → Alert rules**
4. 查找 **SRS No Data Alert (okbps=0,0,0)**
5. 查看狀態：
   - 🟢 **Normal** - 沒有檢測到問題
   - 🟡 **Pending** - 檢測到問題，等待觸發
   - 🔴 **Firing** - 警報已觸發

### 檢查 3: Contact Point 配置

```bash
# 查看當前的 contact point 配置
curl -s -u admin:admin 'http://100.64.0.160:3000/api/v1/provisioning/contact-points' | \
  python3 -m json.tool | grep -A 5 "webhook-api-trigger"
```

**應該看到：**
```json
{
    "name": "webhook-api-trigger",
    "type": "webhook",
    "settings": {
        "url": "http://172.17.0.1:5000/webhook/grafana"
    }
}
```

---

## 🔍 實時監控腳本

使用監控腳本查看完整流程：

```bash
./monitor-alert-system.sh
```

這個腳本會實時顯示：
- Grafana Alert 評估活動
- Webhook 接收記錄
- API 請求發送記錄

---

## 🎯 手動觸發測試

### 方法 1: 產生包含 okbps=0,0,0 的日誌

```bash
echo "[$(date '+%Y-%m-%d %H:%M:%S')][INFO][test] <- CPB time=$(date +%s), okbps=0,0,0, ikbps=0,0,0, mr=0/350, p1stpt=20000, pnt=5000" >> /home/ella/share_folder/srs.log
```

### 方法 2: 直接測試 Webhook 服務

```bash
curl -X POST http://localhost:5000/test \
  -H 'Content-Type: application/json' \
  -d '{
    "tableId": "ARO-001",
    "status": "down"
  }'
```

### 方法 3: 模擬 Grafana Webhook

```bash
curl -X POST http://localhost:5000/webhook/grafana \
  -H 'Content-Type: application/json' \
  -d '{
    "status": "firing",
    "alerts": [{
      "labels": {"alertname": "SRSNoDataAlert"},
      "annotations": {"table_id": "ARO-001"}
    }]
  }'
```

---

## 📋 檢查清單

完整驗證流程：

- [ ] 1. 確認 Promtail test agent 正在運行
  ```bash
  docker ps | grep test-agent
  ```

- [ ] 2. 確認 Webhook 服務正在運行
  ```bash
  ps aux | grep grafana_webhook_service
  ```

- [ ] 3. 確認 Grafana 正在運行
  ```bash
  docker ps | grep grafana
  ```

- [ ] 4. 查看 Loki 中是否有 okbps=0,0,0 日誌
  - 在 Grafana Explore 查詢：`{job="srs_test"} |= "okbps=0,0,0"`

- [ ] 5. 檢查 Grafana Alert Rule 是否在評估
  ```bash
  docker logs kevin-telemetry-grafana --since 2m 2>&1 | grep srs-okbps
  ```

- [ ] 6. 查看 Webhook 日誌是否收到請求
  ```bash
  tail -f webhook_service.log
  ```

- [ ] 7. 確認 API 請求已發送
  ```bash
  grep "API Response" webhook_service.log
  ```

---

## ⚠️ 常見問題排查

### 問題 1: Alert 未檢測到日誌

**檢查：**
```bash
# 確認 test agent 正在運行
./start-test-agent.sh tpe

# 確認日誌檔案有內容
tail /home/ella/share_folder/srs.log
```

### 問題 2: Webhook 未收到請求

**可能原因：**
- Contact point URL 不正確
- Webhook 服務未運行
- 網路連接問題

**解決：**
```bash
# 重啟 webhook 服務
./stop-webhook-service.sh
./start-webhook-service.sh

# 檢查 contact point
curl -s -u admin:admin 'http://100.64.0.160:3000/api/v1/provisioning/contact-points'
```

### 問題 3: API 請求失敗

**檢查 webhook 日誌：**
```bash
grep -A 5 "API request error" webhook_service.log
```

**可能原因：**
- API endpoint 不可用 (100.64.0.160:8085)
- API 拒絕請求
- 網路問題

---

## 📝 日誌示例

### 成功流程的完整日誌

**1. Grafana 檢測到警報：**
```
logger=ngalert.sender.router rule_uid=srs-okbps-zero-alert org_id=1 
msg="Sending alerts to local notifier" count=23
```

**2. Webhook 服務收到請求：**
```
2025-10-01 16:05:30 - __main__ - INFO - Received Grafana alert: {...}
2025-10-01 16:05:30 - __main__ - INFO - Alert status: firing
2025-10-01 16:05:30 - __main__ - INFO - Processing alert: SRSNoDataAlert
```

**3. 發送 API 請求：**
```
2025-10-01 16:05:30 - __main__ - INFO - Sending API request to http://100.64.0.160:8085/v1/service/status
2025-10-01 16:05:30 - __main__ - INFO - Payload: {"tableId": "ARO-001", "zCam": "down"}
```

**4. 收到 API 響應：**
```
2025-10-01 16:05:30 - __main__ - INFO - API Response Status: 200
2025-10-01 16:05:30 - __main__ - INFO - Successfully sent status update for table ARO-001
```

---

## 🎓 總結

要確認系統正常運作，需要在以下 3 個地方查看日誌：

1. **Grafana 容器日誌** - 確認 alert rule 在評估和發送警報
2. **Webhook 服務日誌** - 確認收到 Grafana 的 webhook 請求
3. **Webhook 服務日誌** - 確認成功發送 API 請求到 100.64.0.160:8085

使用 `./monitor-alert-system.sh` 可以同時監控所有這些流程！

