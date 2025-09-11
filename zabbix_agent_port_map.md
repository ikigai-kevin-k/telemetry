# Zabbix Agent 端口映射配置指南

## 問題描述

當 Zabbix Agent 運行在 Docker 容器中時，如果沒有正確配置端口映射，會導致 Zabbix Server 無法連接到 Agent，出現以下錯誤：

- Zabbix Web Dashboard 顯示連接警告
- `zabbix_get` 命令返回 "Connection refused" 錯誤
- Agent 日誌顯示 "connection rejected, allowed hosts" 錯誤

## 根本原因

1. **端口未映射**：Zabbix Agent 容器的端口 10050 沒有映射到主機
2. **網路配置問題**：Agent 只允許特定 IP 的連接，但 Server 使用內部網路 IP

## 解決方案

### 1. 檢查當前容器狀態

```bash
# 檢查容器是否運行
docker ps | grep zabbix-agent

# 檢查端口映射
docker inspect kevin-telemetry-zabbix-agent | grep -A 5 -B 5 PortBindings

# 檢查網路連接
nmap -p 10050 <agent_host_ip>
```

### 2. 停止並移除舊容器

```bash
# 停止容器
docker stop kevin-telemetry-zabbix-agent

# 移除容器
docker rm kevin-telemetry-zabbix-agent
```

### 3. 更新 Agent 配置文件

編輯 `/home/rnd/telemetry/zabbix/agent2.conf`：

```ini
# 允許來自 Zabbix Server 的連接
Server=100.64.0.113,172.18.0.1
ServerActive=100.64.0.113,172.18.0.1
Hostname=GC-ARO-001-2-agent

# 其他配置...
ListenPort=10050
ListenIP=0.0.0.0
```

### 4. 重新啟動容器（正確方式）

```bash
docker run -d \
  --name kevin-telemetry-zabbix-agent \
  --network telemetry_monitoring \
  -p 10050:10050 \
  -e ZBX_HOSTNAME=GC-ARO-001-2-agent \
  -e ZBX_SERVER_HOST=100.64.0.113 \
  -e ZBX_SERVER_PORT=10051 \
  -e ZBX_ENABLEPERSISTENTBUFFER=1 \
  -v /home/rnd/telemetry/zabbix/agent2.conf:/etc/zabbix/zabbix_agent2.conf \
  -v /home/rnd/telemetry/zabbix/scripts:/var/lib/zabbix/scripts \
  --restart unless-stopped \
  zabbix/zabbix-agent2:ubuntu-6.0-latest
```

### 5. 驗證配置

```bash
# 檢查容器狀態
docker ps | grep zabbix-agent

# 檢查端口映射
docker port kevin-telemetry-zabbix-agent

# 測試網路連接
nmap -p 10050 <agent_host_ip>

# 測試 Zabbix 連接
docker exec kevin-telemetry-zabbix-server zabbix_get -s <agent_host_ip> -k agent.ping
docker exec kevin-telemetry-zabbix-server zabbix_get -s <agent_host_ip> -k system.uptime
```

## 正確的 Docker Compose 配置

為了避免手動配置，建議在 `docker-compose.yml` 中正確配置：

```yaml
# Zabbix Agent
zabbix-agent:
  image: zabbix/zabbix-agent2:ubuntu-6.0-latest
  container_name: kevin-telemetry-zabbix-agent
  ports:
    - "10050:10050"  # 重要：添加端口映射
  environment:
    - ZBX_HOSTNAME=GC-ARO-001-2-agent
    - ZBX_SERVER_HOST=100.64.0.113
    - ZBX_SERVER_PORT=10051
    - ZBX_ENABLEPERSISTENTBUFFER=1
  volumes:
    - ./zabbix/agent2.conf:/etc/zabbix/zabbix_agent2.conf
    - ./zabbix/scripts:/var/lib/zabbix/scripts
  restart: unless-stopped
  networks:
    - monitoring
  depends_on:
    - zabbix-server
```

## 網路配置最佳實踐

### 1. Agent 配置文件 (`agent2.conf`)

```ini
# 基本配置
Server=100.64.0.113,172.18.0.1  # 允許多個 Server IP
ServerActive=100.64.0.113,172.18.0.1
Hostname=GC-ARO-001-2-agent

# 網路設定
ListenPort=10050
ListenIP=0.0.0.0  # 監聽所有介面

# 安全設定
AllowKey=system.run[*]
AllowKey=system.run[curl*]

# 超時設定
Timeout=30
```

### 2. 防火牆配置

確保主機防火牆允許端口 10050：

```bash
# Ubuntu/Debian
sudo ufw allow 10050/tcp

# CentOS/RHEL
sudo firewall-cmd --permanent --add-port=10050/tcp
sudo firewall-cmd --reload
```

## 故障排除

### 1. 檢查容器日誌

```bash
# 查看 Agent 日誌
docker logs kevin-telemetry-zabbix-agent

# 查看 Server 日誌
docker logs kevin-telemetry-zabbix-server
```

### 2. 常見錯誤及解決方法

| 錯誤訊息 | 原因 | 解決方法 |
|---------|------|---------|
| `Connection refused` | 端口未映射 | 添加 `-p 10050:10050` |
| `connection rejected, allowed hosts` | 網路配置問題 | 更新 `Server` 配置 |
| `ZBX_TCP_READ() failed` | 網路連接問題 | 檢查防火牆和網路 |

### 3. 網路診斷命令

```bash
# 檢查端口狀態
netstat -tlnp | grep 10050

# 檢查容器網路
docker network inspect telemetry_monitoring

# 測試連接
telnet <agent_host_ip> 10050
```

## 監控驗證

### 1. 檢查 Zabbix Web Dashboard

- 系統資訊警告應該消失
- Host 狀態顯示為 "Available"
- 問題列表中的連接錯誤應該解決

### 2. 檢查數據收集

```bash
# 測試基本監控項目
docker exec kevin-telemetry-zabbix-server zabbix_get -s <agent_host_ip> -k agent.ping
docker exec kevin-telemetry-zabbix-server zabbix_get -s <agent_host_ip> -k system.uptime
docker exec kevin-telemetry-zabbix-server zabbix_get -s <agent_host_ip> -k system.cpu.util[,idle]
```

## 總結

正確的 Zabbix Agent Docker 配置需要：

1. ✅ **端口映射**：`-p 10050:10050`
2. ✅ **網路配置**：允許 Server IP 連接
3. ✅ **防火牆設定**：開放端口 10050
4. ✅ **容器重啟**：使用正確的參數重新啟動

遵循這些步驟可以確保 Zabbix Agent 在 Docker 環境中正常運行，並與 Zabbix Server 建立穩定的連接。
