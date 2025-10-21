# TPE Server 運行提醒

## 服務啟動與停止

### 啟動所有服務（TPE Server）
```bash
cd /home/ella/kevin/telemetry
SERVER_IP=100.64.0.160 docker compose up -d
```

### 停止所有服務
```bash
cd /home/ella/kevin/telemetry
SERVER_IP=100.64.0.160 docker compose down
```

### 重啟所有服務
```bash
cd /home/ella/kevin/telemetry
SERVER_IP=100.64.0.160 docker compose down
SERVER_IP=100.64.0.160 docker compose up -d
```

## 服務訪問地址

### 主要監控服務
- **Grafana**: http://100.64.0.160:3000
  - 帳號: `admin`
  - 密碼: `admin`
  
- **Prometheus**: http://100.64.0.160:9090
  
- **Alertmanager**: http://100.64.0.160:9093
  
- **Pushgateway**: http://100.64.0.160:9091
  
- **Loki**: http://100.64.0.160:3100

### Zabbix 服務
- **Zabbix Web**: http://100.64.0.160:8080

### 本機訪問（在伺服器上）
- **Grafana**: http://localhost:3000 或 http://192.168.20.9:3000
- **Prometheus**: http://localhost:9090
- **Alertmanager**: http://localhost:9093

## 服務狀態檢查

### 檢查所有容器狀態
```bash
docker ps --filter "name=kevin-telemetry" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

### 檢查 Prometheus 配置
```bash
docker inspect kevin-telemetry-prometheus --format '{{range .Args}}{{println .}}{{end}}' | grep external-url
```

### 檢查 Alertmanager 配置
```bash
docker inspect kevin-telemetry-alertmanager --format '{{range .Args}}{{println .}}{{end}}' | grep external-url
```

### 檢查服務日誌
```bash
# Grafana
docker logs kevin-telemetry-grafana --tail 50

# Prometheus
docker logs kevin-telemetry-prometheus --tail 50

# Alertmanager
docker logs kevin-telemetry-alertmanager --tail 50
```

## 重要配置資訊

### Server IP 設定
- **TPE Server**: `100.64.0.160`
- **GE Server**: `100.64.0.113` (預設)

### 網路配置
- **Local IP**: `192.168.20.9/24` (網卡 eno1)
- **WireGuard IP**: `100.64.0.160`

### 容器網路模式
- **Grafana**: `host` 模式（直接使用主機端口 3000）
- **Webhook**: `host` 模式
- **其他服務**: `bridge` 模式（使用端口映射）

## 內網訪問說明

### 從不同網段訪問
如果從不同網段（例如 `192.168.10.x`）無法直接訪問 `192.168.20.9`，請使用 WireGuard VPN IP：

```
http://100.64.0.160:3000
```

### 防火牆檢查
如需檢查防火牆狀態：
```bash
sudo ufw status
```

## 持久化數據

所有服務數據都存儲在 Docker volumes 中：
- `prometheus_data`: Prometheus 時序數據
- `alertmanager_data`: Alertmanager 數據
- `grafana_data`: Grafana 配置和儀表板
- `loki_data`: Loki 日誌數據
- `zabbix_server_data`: Zabbix Server 數據
- `zabbix_db_data`: Zabbix 數據庫

## 配置檔案位置

- **Docker Compose**: `/home/ella/kevin/telemetry/docker-compose.yml`
- **Prometheus Config**: `/home/ella/kevin/telemetry/prometheus.yml`
- **Grafana Config**: `/home/ella/kevin/telemetry/grafana/grafana.ini`
- **Grafana Provisioning**: `/home/ella/kevin/telemetry/grafana/provisioning/`
- **Alert Rules**: `/home/ella/kevin/telemetry/grafana/provisioning/alerting/`

## 環境變數

### 必要環境變數
- `SERVER_IP`: 設定為 `100.64.0.160` (TPE) 或 `100.64.0.113` (GE)

### 可選環境變數
- `SLACK_WEBHOOK_URL`: Slack 通知 webhook URL（目前未設定）

## 故障排除

### 服務無法啟動
1. 檢查容器日誌
2. 確認端口未被占用
3. 檢查 Docker 服務狀態：`systemctl status docker`

### 無法訪問服務
1. 確認服務正在運行：`docker ps`
2. 檢查端口監聽：`ss -tlnp | grep <port>`
3. 檢查防火牆規則
4. 確認使用正確的 IP 地址（VPN IP: 100.64.0.160）

### 配置變更後
如需套用配置變更，重啟相關服務：
```bash
SERVER_IP=100.64.0.160 docker compose restart <service-name>
```

---
**最後更新**: 2025-10-13
**伺服器**: TPE (100.64.0.160)


