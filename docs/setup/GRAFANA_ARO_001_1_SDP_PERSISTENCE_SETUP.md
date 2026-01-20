# Grafana aro11 SDP Log 持久化儲存設定

## 概述

此設定將 Grafana 中關於 Loki datasource 的 aro11 SDP log 配置進行 Docker 持久化儲存，確保容器重啟後設定和資料不會遺失。

## 架構說明

- **主伺服器**: 100.64.0.113 (GC-aro21) - 運行 Grafana、Loki Server
- **aro11 Agent**: 100.64.0.167 (GC-aro11-agent) - 運行 Promtail，收集 SDP logs

## 已完成的設定

### 1. Grafana Datasource 設定 (`grafana/provisioning/datasources/loki.yml`)

新增了專門針對 aro11 SDP logs 的 Loki datasource:

```yaml
# Dedicated datasource for aro11 SDP logs with specific configuration
- name: Loki-aro11-SDP
  type: loki
  access: proxy
  url: http://loki:3100
  isDefault: false
  editable: true
  jsonData:
    # Default query settings for aro11 SDP logs
    derivedFields:
      - name: "Timestamp"
        matcherRegex: "\\[([0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\\.[0-9]{3})\\]"
        url: ""
      - name: "Direction"
        matcherRegex: "\\] (Receive|Send|WebSocket) "
        url: ""
    # Pre-configured filters for SDP logs
    maxLines: 5000
    timeout: "30s"
  # Default query for aro11 SDP logs
  uid: loki-aro11-sdp
```

### 2. Grafana Dashboard 設定

建立了專門的 aro11 SDP Log Dashboard:

- **檔案位置**: `grafana/provisioning/dashboards/aro11-sdp-logs.json`
- **Dashboard ID**: `aro11-sdp-dashboard`
- **資料夾**: SDP Monitoring

#### Dashboard 功能:
1. **SDP Log Rate**: 顯示每分鐘的 log 數量趨勢
2. **Recent Activity Table**: 顯示最新的 SDP log 活動
3. **Message Direction Distribution**: 圓餅圖顯示 Receive/Send/WebSocket 訊息分布
4. **Total Messages**: 統計面板顯示總訊息數

### 3. Docker Compose 持久化設定

更新了主伺服器的 `docker-compose.yml` Grafana 服務設定:

```yaml
grafana:
  image: grafana/grafana:9.5.21
  container_name: kevin-telemetry-grafana
  ports:
    - "3000:3000"
  volumes:
    # Persistent data storage for Grafana
    - grafana_data:/var/lib/grafana
    # Configuration and provisioning files - persistent mount
    - ./grafana/provisioning:/etc/grafana/provisioning:ro
    - ./grafana/grafana.ini:/etc/grafana/grafana.ini:ro
    # Ensure provisioning directories are accessible
    - ./grafana/provisioning/datasources:/etc/grafana/provisioning/datasources:ro
    - ./grafana/provisioning/dashboards:/etc/grafana/provisioning/dashboards:ro
  environment:
    - GF_SECURITY_ADMIN_USER=admin
    - GF_SECURITY_ADMIN_PASSWORD=admin
    - GF_USERS_ALLOW_SIGN_UP=false
    # Enable provisioning and auto-reload
    - GF_PATHS_PROVISIONING=/etc/grafana/provisioning
    - GF_PROVISIONING_DATASOURCES_PATH=/etc/grafana/provisioning/datasources
    - GF_PROVISIONING_DASHBOARDS_PATH=/etc/grafana/provisioning/dashboards
    # Timezone setting for aro11 SDP logs
    - TZ=Asia/Taipei
```

### 4. aro11 Agent 持久化設定

aro11 agent 的 `docker-compose-GC-aro11-agent.yml` 已包含持久化 volumes:

```yaml
volumes:
  promtail_aro_001_1_positions:
    name: telemetry_promtail_aro_001_1_positions
    external: true
  promtail_aro_001_1_data:
    name: telemetry_promtail_aro_001_1_data
    external: true
  zabbix_agent_aro_001_1_data:
    name: telemetry_zabbix_agent_aro_001_1_data
    external: true
```

## 部署和管理

### 管理腳本

提供了 `manage-grafana-persistence.sh` 腳本來管理整個設定:

```bash
# 完整設定流程
./manage-grafana-persistence.sh setup

# 檢查狀態
./manage-grafana-persistence.sh status

# 僅重啟 Grafana
./manage-grafana-persistence.sh restart

# 備份 Grafana 資料
./manage-grafana-persistence.sh backup
```

### 手動部署步驟

1. **在主伺服器 (100.64.0.113) 上**:
   ```bash
   cd /home/rnd/telemetry
   
   # 停止 Grafana 容器
   docker-compose stop grafana
   
   # 重新啟動 Grafana (載入新設定)
   docker-compose up -d grafana
   
   # 檢查狀態
   docker logs kevin-telemetry-grafana
   ```

2. **確認 aro11 agent volumes 存在**:
   ```bash
   # 檢查 volumes
   docker volume ls | grep aro_001_1
   
   # 如果不存在，建立它們
   docker volume create telemetry_promtail_aro_001_1_positions
   docker volume create telemetry_promtail_aro_001_1_data
   docker volume create telemetry_zabbix_agent_aro_001_1_data
   ```

## 驗證設定

### 1. 檢查 Grafana Datasource

訪問 Grafana: http://100.64.0.113:3000
- 用戶名: admin
- 密碼: admin

前往 Configuration > Data Sources，應該看到:
- Loki (原有的)
- **Loki-aro11-SDP** (新增的)

### 2. 檢查 Dashboard

前往 Dashboards，在 "SDP Monitoring" 資料夾中應該看到:
- **aro11 SDP Log Dashboard**

### 3. 檢查 Log 資料

在 dashboard 中應該能看到來自 aro11 的 SDP log 資料:
- Job: studio_sdp_roulette
- Instance: GC-aro11-agent

## 故障排除

### 1. Grafana 無法載入 Datasource

```bash
# 檢查 Grafana 日誌
docker logs kevin-telemetry-grafana

# 檢查 provisioning 檔案權限
ls -la grafana/provisioning/datasources/
ls -la grafana/provisioning/dashboards/
```

### 2. 看不到 aro11 的 Log 資料

```bash
# 檢查 aro11 agent 是否運行
ping 100.64.0.167

# 檢查 Promtail 是否正常運行
ssh user@100.64.0.167 'docker ps | grep promtail'

# 檢查 Loki 是否收到資料
curl -G -s "http://localhost:3100/loki/api/v1/label" | jq
```

### 3. Dashboard 顯示異常

- 檢查時區設定是否為 Asia/Taipei
- 確認 Loki-aro11-SDP datasource 是否正常連接
- 檢查 log 格式是否符合 regex 設定

## 備份和恢復

### 備份

```bash
# 使用管理腳本備份
./manage-grafana-persistence.sh backup

# 手動備份 Grafana volume
docker run --rm -v telemetry_grafana_data:/data -v $(pwd)/backup:/backup alpine:latest \
  sh -c "cd /data && tar czf /backup/grafana_$(date +%Y%m%d_%H%M%S).tar.gz ."
```

### 恢復

```bash
# 停止 Grafana
docker-compose stop grafana

# 恢復資料 (替換 BACKUP_FILE 為實際檔案名)
docker run --rm -v telemetry_grafana_data:/data -v $(pwd)/backup:/backup alpine:latest \
  sh -c "cd /data && tar xzf /backup/BACKUP_FILE.tar.gz"

# 重啟 Grafana
docker-compose up -d grafana
```

## 維護建議

1. **定期備份**: 建議每週備份 Grafana 資料
2. **監控磁碟空間**: 監控 Docker volumes 的磁碟使用量
3. **日誌輪轉**: 確保 aro11 的 SDP log 檔案有適當的輪轉機制
4. **網路連線**: 定期檢查主伺服器與 aro11 之間的網路連線

## 相關檔案

- `docker-compose.yml` - 主伺服器 Docker Compose 設定
- `docker-compose-GC-aro11-agent.yml` - aro11 agent Docker Compose 設定
- `grafana/provisioning/datasources/loki.yml` - Loki datasource 設定
- `grafana/provisioning/dashboards/aro11-sdp-logs.json` - aro11 SDP dashboard
- `grafana/provisioning/dashboards/dashboards.yml` - Dashboard provisioning 設定
- `promtail-GC-aro11-agent.yml` - aro11 Promtail 設定
- `manage-grafana-persistence.sh` - 管理腳本
