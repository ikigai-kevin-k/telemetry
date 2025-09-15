# Docker 容器資源統計指令集

## 基本容器狀態檢查

### 查看所有運行中的容器
```bash
docker ps
```

### 篩選特定容器
```bash
docker ps | grep kevin
```

## 資源使用統計

### 即時資源使用統計（CPU、記憶體、網路、磁碟 I/O）
```bash
docker stats kevin-telemetry-zabbix-agent kevin-telemetry-promtail-agent --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}"
```

### 持續監控資源使用（即時更新）
```bash
docker stats kevin-telemetry-zabbix-agent kevin-telemetry-promtail-agent
```

## 儲存空間統計

### 查看 Docker 系統儲存使用情況
```bash
docker system df -v | grep -E "(kevin-telemetry-zabbix-agent|kevin-telemetry-promtail-agent)"
```

### 查看容器內部儲存使用情況
```bash
# Zabbix Agent 容器
docker exec kevin-telemetry-zabbix-agent df -h / 2>/dev/null || echo "無法取得 zabbix-agent 儲存資訊"

# Promtail Agent 容器
docker exec kevin-telemetry-promtail-agent df -h / 2>/dev/null || echo "無法取得 promtail-agent 儲存資訊"
```

## 容器詳細資訊

### 查看容器狀態、啟動時間、重啟次數
```bash
docker inspect kevin-telemetry-zabbix-agent kevin-telemetry-promtail-agent --format='{{.Name}}: {{.State.Status}} - Started: {{.State.StartedAt}} - RestartCount: {{.RestartCount}}'
```

### 查看容器完整詳細資訊
```bash
docker inspect kevin-telemetry-zabbix-agent
docker inspect kevin-telemetry-promtail-agent
```

## 進階監控指令

### 查看容器日誌
```bash
# 查看最近 100 行日誌
docker logs --tail 100 kevin-telemetry-zabbix-agent
docker logs --tail 100 kevin-telemetry-promtail-agent

# 即時追蹤日誌
docker logs -f kevin-telemetry-zabbix-agent
docker logs -f kevin-telemetry-promtail-agent
```

### 查看容器進程
```bash
docker top kevin-telemetry-zabbix-agent
docker top kevin-telemetry-promtail-agent
```

### 查看容器資源限制
```bash
docker inspect kevin-telemetry-zabbix-agent --format='{{.HostConfig.Memory}} {{.HostConfig.CpuQuota}} {{.HostConfig.CpuPeriod}}'
docker inspect kevin-telemetry-promtail-agent --format='{{.HostConfig.Memory}} {{.HostConfig.CpuQuota}} {{.HostConfig.CpuPeriod}}'
```

## 一鍵統計腳本

### 建立統計腳本
```bash
#!/bin/bash
# container_stats.sh

echo "=== Docker 容器資源統計 ==="
echo "時間: $(date)"
echo ""

echo "=== 容器狀態 ==="
docker ps | grep kevin

echo ""
echo "=== 資源使用統計 ==="
docker stats kevin-telemetry-zabbix-agent kevin-telemetry-promtail-agent --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}"

echo ""
echo "=== 儲存空間使用 ==="
docker system df -v | grep -E "(kevin-telemetry-zabbix-agent|kevin-telemetry-promtail-agent)"

echo ""
echo "=== 容器詳細資訊 ==="
docker inspect kevin-telemetry-zabbix-agent kevin-telemetry-promtail-agent --format='{{.Name}}: {{.State.Status}} - Started: {{.State.StartedAt}} - RestartCount: {{.RestartCount}}'
```

### 執行統計腳本
```bash
chmod +x container_stats.sh
./container_stats.sh
```

## 注意事項

1. **權限要求**: 執行這些指令需要 Docker 管理員權限
2. **容器名稱**: 確保容器名稱正確，可先使用 `docker ps` 確認
3. **錯誤處理**: 部分指令包含錯誤處理，避免因容器不存在而中斷
4. **資源監控**: 建議定期執行這些指令來監控容器健康狀態
5. **日誌管理**: 大量日誌可能影響系統效能，建議設定日誌輪轉

## 相關檔案位置

- 此指令集檔案: `/home/rnd/telemetry/container_stats_commands.md`
- 工作目錄: `/home/rnd/telemetry`
