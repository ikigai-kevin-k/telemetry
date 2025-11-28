# ARO-002-1 Agent 自動啟動設定指南

## 問題描述

ARO-002-1 agent 在 PC reboot 之後沒有重新自動執行相關程式推送資料到 server，導致 AIPC Network Traffic 資料中斷。

## 解決方案

已建立以下檔案來確保 agent 在開機時自動啟動：

1. **啟動腳本**: `start-aro-002-1-agent.sh`
   - 檢查 Docker daemon 狀態
   - 確保必要的 Docker volumes 存在
   - 啟動 Docker 容器（Promtail 和 Zabbix Agent）

2. **Systemd Service**: `telemetry-aro-002-1-agent.service`
   - 在系統開機時自動執行
   - 依賴 Docker service 和網路連線
   - 支援自動重啟（on-failure）

## 安裝步驟

### 1. 安裝 Systemd Service

```bash
# 複製 service 檔案到 systemd 目錄
sudo cp /home/rnd/telemetry/telemetry-aro-002-1-agent.service /etc/systemd/system/

# 重新載入 systemd daemon
sudo systemctl daemon-reload

# 啟用服務（開機自動啟動）
sudo systemctl enable telemetry-aro-002-1-agent.service

# 啟動服務（立即執行）
sudo systemctl start telemetry-aro-002-1-agent.service
```

### 2. 驗證服務狀態

```bash
# 檢查服務狀態
sudo systemctl status telemetry-aro-002-1-agent.service

# 檢查 Docker 容器狀態
docker compose -f /home/rnd/telemetry/docker-compose-GC-ARO-002-1-agent.yml ps

# 查看服務日誌
sudo journalctl -u telemetry-aro-002-1-agent.service -f
```

### 3. 測試自動啟動

```bash
# 重啟系統測試（請在安全時間進行）
sudo reboot

# 重啟後檢查服務狀態
sudo systemctl status telemetry-aro-002-1-agent.service
docker compose -f /home/rnd/telemetry/docker-compose-GC-ARO-002-1-agent.yml ps
```

## 手動操作

### 手動啟動 Agent

```bash
/home/rnd/telemetry/start-aro-002-1-agent.sh
```

### 手動停止 Agent

```bash
docker compose -f /home/rnd/telemetry/docker-compose-GC-ARO-002-1-agent.yml down
```

或使用 systemd：

```bash
sudo systemctl stop telemetry-aro-002-1-agent.service
```

### 重啟 Agent

```bash
sudo systemctl restart telemetry-aro-002-1-agent.service
```

## 服務管理命令

```bash
# 啟用開機自動啟動
sudo systemctl enable telemetry-aro-002-1-agent.service

# 停用開機自動啟動
sudo systemctl disable telemetry-aro-002-1-agent.service

# 查看服務狀態
sudo systemctl status telemetry-aro-002-1-agent.service

# 查看服務日誌
sudo journalctl -u telemetry-aro-002-1-agent.service

# 查看最近的日誌（即時）
sudo journalctl -u telemetry-aro-002-1-agent.service -f

# 查看服務日誌（最近 100 行）
sudo journalctl -u telemetry-aro-002-1-agent.service -n 100
```

## 故障排除

### 問題 1: 服務無法啟動

**檢查 Docker daemon 狀態**:
```bash
sudo systemctl status docker
```

**檢查服務日誌**:
```bash
sudo journalctl -u telemetry-aro-002-1-agent.service -n 50
```

### 問題 2: 容器無法啟動

**檢查 Docker compose 檔案**:
```bash
cd /home/rnd/telemetry
docker compose -f docker-compose-GC-ARO-002-1-agent.yml config
```

**檢查容器日誌**:
```bash
docker compose -f /home/rnd/telemetry/docker-compose-GC-ARO-002-1-agent.yml logs
```

### 問題 3: Volumes 不存在

**手動建立 volumes**:
```bash
docker volume create telemetry_promtail_aro_002_1_positions
docker volume create telemetry_promtail_aro_002_1_data
docker volume create telemetry_zabbix_agent_aro_002_1_data
```

### 問題 4: 網路連線問題

**檢查網路連線**:
```bash
# 檢查 server 連線
ping -c 3 100.64.0.113

# 檢查 Loki 服務
curl -s http://100.64.0.113:3100/ready

# 檢查 Zabbix 服務
telnet 100.64.0.113 10051
```

## 驗證資料推送

### 檢查 Promtail 是否正常運作

```bash
# 查看 Promtail 容器日誌
docker logs telemetry-promtail-GC-aro21-agent -f

# 檢查 Loki 是否有收到資料
curl -s -G "http://100.64.0.113:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={job="promtail"}' \
  --data-urlencode 'start='$(date -d '10 minutes ago' -u +%Y-%m-%dT%H:%M:%SZ) \
  --data-urlencode 'end='$(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --data-urlencode 'limit=5'
```

### 檢查 Zabbix Agent 是否正常運作

```bash
# 查看 Zabbix Agent 容器日誌
docker logs telemetry-zabbix-agent-GC-aro21-agent -f

# 在 Zabbix Server 上檢查 agent 連線狀態
# 登入 Zabbix Web UI: http://100.64.0.113:8080
# 檢查 Configuration > Hosts > GC-ARO-002-1-agent
```

### 檢查 AIPC Network Traffic 資料

1. 登入 Grafana: http://100.64.0.113:3000
2. 開啟 "AIPC Network Traffic - All Agents" dashboard
3. 確認 ARO12 (GC-ARO-002-1-agent) 的資料線是否正常顯示

## 注意事項

1. **Docker daemon 必須在開機時自動啟動**
   - 如果 Docker 沒有設定為開機自動啟動，systemd service 會等待 Docker 啟動
   - 確保 Docker service 已啟用：`sudo systemctl enable docker`

2. **網路連線**
   - Agent 需要能夠連線到 server (100.64.0.113)
   - 確保防火牆規則允許連線

3. **權限**
   - Service 以 `rnd` 使用者執行
   - 確保 `rnd` 使用者有權限執行 Docker 命令（通常需要加入 docker group）

4. **Volumes**
   - Docker volumes 必須存在，否則容器無法啟動
   - 啟動腳本會自動檢查並建立 volumes

## 相關檔案

- `start-aro-002-1-agent.sh` - 啟動腳本
- `telemetry-aro-002-1-agent.service` - Systemd service 檔案
- `docker-compose-GC-ARO-002-1-agent.yml` - Docker Compose 配置
- `zabbix/agent2-GC-ARO-002-1-agent.conf` - Zabbix Agent 配置
- `promtail-GC-ARO-002-1-agent.yml` - Promtail 配置

