# Loki Server/Agent 架構說明

## 架構概述

本專案已將 Loki 架構分離為 **Server 端** 和 **Agent 端**，類似於 Zabbix 的 server/agent 模式。

### 🖥️ Server 端 (100.64.0.160 - GC-ARO-002-1)
**運行服務：**
- Loki Server (Port 3100)
- Zabbix Server (Port 10051)
- Zabbix Web Interface (Port 8080)
- Prometheus (Port 9090)
- Grafana (Port 3000)

**啟動方式：**
```bash
./start-server.sh
# 或
docker-compose up -d
```

### 📱 Agent 端 (100.64.0.149 - GC-ARO-001-2)
**運行服務：**
- Loki Agent (Promtail)
- Zabbix Agent (Port 10050)

**啟動方式：**
```bash
./start-agent.sh
# 或
docker-compose -f docker-compose.agent.yml up -d
```

## 網路架構

```
┌─────────────────────────────────┐    ┌─────────────────────────────────┐
│        Server 端                │    │        Agent 端                 │
│    100.64.0.160                │    │    100.64.0.149                │
│                                │    │                                │
│  ┌─────────────────────────┐   │    │  ┌─────────────────────────┐   │
│  │    Loki Server          │◀──┼────┼──│    Promtail Agent       │   │
│  │    Port 3100            │   │    │  │    (Log Collector)      │   │
│  └─────────────────────────┘   │    │  └─────────────────────────┘   │
│                                │    │                                │
│  ┌─────────────────────────┐   │    │  ┌─────────────────────────┐   │
│  │    Zabbix Server        │◀──┼────┼──│    Zabbix Agent          │   │
│  │    Port 10051           │   │    │  │    Port 10050           │   │
│  └─────────────────────────┘   │    │  └─────────────────────────┘   │
│                                │    │                                │
│  ┌─────────────────────────┐   │    │                                │
│  │    Grafana              │   │    │                                │
│  │    Port 3000            │   │    │                                │
│  └─────────────────────────┘   │    │                                │
│                                │    │                                │
│  ┌─────────────────────────┐   │    │                                │
│  │    Prometheus           │   │    │                                │
│  │    Port 9090            │   │    │                                │
│  └─────────────────────────┘   │    │                                │
└─────────────────────────────────┘    └─────────────────────────────────┘
```

## 日誌收集配置

### Agent 端日誌來源
Promtail 在 Agent 端收集以下日誌檔案：
- `/var/log/mock_sicbo.log` - Mock Sicbo 應用程式日誌
- `/var/log/server.log` - 伺服器日誌
- `/var/log/tmux-client.log` - Tmux 客戶端日誌

### 日誌標籤
每個日誌來源都會被標記：
- `job`: 日誌來源類型 (mock_sicbo, server, tmux_client)
- `instance`: Agent 實例識別碼 (GC-ARO-001-2-agent)
- `level`: 日誌級別 (僅限 mock_sicbo)
- `logger`: 記錄器名稱 (僅限 mock_sicbo)

## 配置檔案

### Server 端配置
- `docker-compose.yml` - Server 端服務配置
- `loki-config.yml` - Loki Server 配置
- `grafana/provisioning/datasources/loki.yml` - Grafana Loki 資料源

### Agent 端配置
- `docker-compose.agent.yml` - Agent 端服務配置
- `promtail-config.yml` - Promtail Agent 配置
- `zabbix/agent2.conf` - Zabbix Agent 配置

## 部署步驟

### 1. 在 Server 端 (100.64.0.160) 部署
```bash
# 複製專案到 server 端
git clone <repository> /path/to/telemetry
cd /path/to/telemetry

# 啟動 server 服務
./start-server.sh
```

### 2. 在 Agent 端 (100.64.0.149) 部署
```bash
# 複製專案到 agent 端
git clone <repository> /path/to/telemetry
cd /path/to/telemetry

# 啟動 agent 服務
./start-agent.sh
```

## 監控和除錯

### 查看服務狀態
```bash
# Server 端
docker-compose ps

# Agent 端
docker-compose -f docker-compose.agent.yml ps
```

### 查看日誌
```bash
# Server 端
docker-compose logs -f loki
docker-compose logs -f grafana

# Agent 端
docker-compose -f docker-compose.agent.yml logs -f promtail
```

### 測試連接
```bash
# 測試 Loki Server 連接
curl http://100.64.0.160:3100/ready

# 測試 Promtail 到 Loki 的連接
curl -X POST http://100.64.0.160:3100/loki/api/v1/push \
  -H "Content-Type: application/json" \
  -d '{"streams":[{"stream":{"job":"test"},"values":[["'$(date +%s%N)'","test message"]]}]}'
```

## 注意事項

1. **防火牆設定**：確保 Server 端的 3100 和 10051 端口對 Agent 端開放
2. **網路連通性**：確保兩端可以透過 Tailscale 網路互相通訊
3. **日誌檔案權限**：確保 Agent 端有權限讀取日誌檔案
4. **時區設定**：所有服務都設定為 Asia/Taipei 時區

## 故障排除

### 常見問題
1. **Promtail 無法連接到 Loki Server**
   - 檢查網路連通性
   - 確認 Loki Server 正在運行
   - 檢查防火牆設定

2. **Zabbix Agent 無法連接到 Server**
   - 檢查 Zabbix Server 是否正在運行
   - 確認 Agent 配置中的 Server IP 正確

3. **日誌沒有出現在 Grafana 中**
   - 檢查 Promtail 是否正在收集日誌
   - 確認 Loki Server 正在接收日誌
   - 檢查 Grafana 的 Loki 資料源配置
