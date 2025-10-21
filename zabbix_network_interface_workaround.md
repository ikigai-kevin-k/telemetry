# Zabbix Agent 網路介面監控臨時解決方案

## 概述

此解決方案繞過了 Zabbix 設定問題，直接修改 agent side docker service 的程式碼，讓 Grafana explore panel 可以查詢到 `aro12 agent` 的 `net.if.in["enp86s0"]` 的 metrics。

## 問題背景

- Zabbix Agent 在用的 eth interface 是 `enp86s0` 而不是預設的 `eth0`
- Zabbix 模板中的低階自動探索 (LLD) 規則無法正確識別 `enp86s0` 介面
- 需要臨時解決方案讓 Grafana 可以查詢到正確的網路介面 metrics

## 解決方案

### 1. 創建自定義網路監控腳本

創建了 `/home/rnd/telemetry/zabbix/scripts/network_monitor.sh` 腳本，提供以下功能：

- `custom.net.if.in[*]` - 網路介面接收位元組數
- `custom.net.if.out[*]` - 網路介面發送位元組數  
- `custom.net.if.in.packets[*]` - 網路介面接收封包數
- `custom.net.if.out.packets[*]` - 網路介面發送封包數
- `custom.net.if.in.errors[*]` - 網路介面接收錯誤數
- `custom.net.if.out.errors[*]` - 網路介面發送錯誤數
- `custom.net.if.in.dropped[*]` - 網路介面接收丟棄封包數
- `custom.net.if.out.dropped[*]` - 網路介面發送丟棄封包數
- `custom.net.if.speed[*]` - 網路介面速度
- `custom.net.if.status[*]` - 網路介面狀態

### 2. 修改 Zabbix Agent 配置

在 `/home/rnd/telemetry/zabbix/agent2-GC-aro12-agent.conf` 中添加了新的 UserParameter：

```conf
# Network interface monitoring parameters (enp86s0 specific)
UserParameter=custom.net.if.in[*],/var/lib/zabbix/scripts/network_monitor.sh rx_bytes $1
UserParameter=custom.net.if.out[*],/var/lib/zabbix/scripts/network_monitor.sh tx_bytes $1
UserParameter=custom.net.if.in.packets[*],/var/lib/zabbix/scripts/network_monitor.sh rx_packets $1
UserParameter=custom.net.if.out.packets[*],/var/lib/zabbix/scripts/network_monitor.sh tx_packets $1
UserParameter=custom.net.if.in.errors[*],/var/lib/zabbix/scripts/network_monitor.sh rx_errors $1
UserParameter=custom.net.if.out.errors[*],/var/lib/zabbix/scripts/network_monitor.sh tx_errors $1
UserParameter=custom.net.if.in.dropped[*],/var/lib/zabbix/scripts/network_monitor.sh rx_dropped $1
UserParameter=custom.net.if.out.dropped[*],/var/lib/zabbix/scripts/network_monitor.sh tx_dropped $1
UserParameter=custom.net.if.speed[*],/var/lib/zabbix/scripts/network_monitor.sh speed $1
UserParameter=custom.net.if.status[*],/var/lib/zabbix/scripts/network_monitor.sh status $1
```

### 3. 修改 Docker 配置

修改了 `/home/rnd/telemetry/docker-compose-GC-aro12-agent.yml`，使用 `network_mode: host` 讓容器可以訪問宿主機的網路介面：

```yaml
zabbix-agent:
  image: zabbix/zabbix-agent2:ubuntu-6.0-latest
  container_name: telemetry-zabbix-agent-GC-aro12-agent
  ports:
    - "10050:10050"
  environment:
    - ZBX_HOSTNAME=GC-aro12-agent
    - ZBX_SERVER_HOST=100.64.0.113
    - ZBX_SERVER_ACTIVE=100.64.0.113
    - ZBX_SERVER_PORT=10051
    - ZBX_ENABLEPERSISTENTBUFFER=1
  volumes:
    - ./zabbix/agent2-GC-aro12-agent.conf:/etc/zabbix/zabbix_agent2.conf
    - ./zabbix/scripts:/var/lib/zabbix/scripts
  network_mode: host  # Use host networking to access host network interfaces
  restart: unless-stopped
```

## 使用方法

### 在 Zabbix 中查詢 Metrics

現在可以在 Zabbix 中使用以下 keys 查詢 `enp86s0` 介面的數據：

- `custom.net.if.in[enp86s0]` - 接收位元組數
- `custom.net.if.out[enp86s0]` - 發送位元組數
- `custom.net.if.in.packets[enp86s0]` - 接收封包數
- `custom.net.if.out.packets[enp86s0]` - 發送封包數
- `custom.net.if.status[enp86s0]` - 介面狀態 (1=up, 0=down)

### 在 Grafana 中查詢

在 Grafana Explore panel 中，可以使用 Zabbix datasource 查詢：

```
custom.net.if.in[enp86s0]
custom.net.if.out[enp86s0]
```

### 測試腳本

可以直接測試腳本功能：

```bash
# 測試接收位元組數
./zabbix/scripts/network_monitor.sh rx_bytes enp86s0

# 測試發送位元組數  
./zabbix/scripts/network_monitor.sh tx_bytes enp86s0

# 測試介面狀態
./zabbix/scripts/network_monitor.sh status enp86s0
```

## 驗證

已驗證以下 metrics 正常工作：

- ✅ `custom.net.if.in[enp86s0]` - 返回接收位元組數
- ✅ `custom.net.if.out[enp86s0]` - 返回發送位元組數  
- ✅ `custom.net.if.status[enp86s0]` - 返回介面狀態 (1=up)

## 注意事項

1. **臨時解決方案**：這是繞過 Zabbix 設定的臨時解決方案，建議後續修正 Zabbix 模板的 LLD 規則
2. **Host Networking**：使用 `network_mode: host` 讓容器可以訪問宿主機網路介面
3. **自定義 Keys**：使用 `custom.` 前綴避免與 Zabbix 內建 keys 衝突
4. **腳本權限**：確保腳本有執行權限 (`chmod +x`)

## 後續建議

1. 修正 Zabbix 模板的 LLD 規則，讓其能正確識別 `enp86s0` 介面
2. 考慮將此解決方案應用到其他 agent 節點
3. 在 Grafana 中創建專門的 dashboard 來監控網路介面流量

## 故障排除

如果 metrics 無法正常工作：

1. 檢查容器是否使用 host networking：`docker inspect telemetry-zabbix-agent-GC-aro12-agent | grep NetworkMode`
2. 檢查腳本權限：`ls -la /home/rnd/telemetry/zabbix/scripts/network_monitor.sh`
3. 檢查腳本執行：`docker exec telemetry-zabbix-agent-GC-aro12-agent /var/lib/zabbix/scripts/network_monitor.sh rx_bytes enp86s0`
4. 檢查 Zabbix agent 日誌：`docker logs telemetry-zabbix-agent-GC-aro12-agent`
