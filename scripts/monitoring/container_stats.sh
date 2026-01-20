#!/bin/bash
# Docker 容器資源統計腳本
# 用於監控 kevin-telemetry-zabbix-agent 和 kevin-telemetry-promtail-agent 的資源使用情況

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

echo ""
echo "=== 容器內部儲存使用 ==="
echo "Zabbix Agent 容器:"
docker exec kevin-telemetry-zabbix-agent df -h / 2>/dev/null || echo "無法取得 zabbix-agent 儲存資訊"

echo ""
echo "Promtail Agent 容器:"
docker exec kevin-telemetry-promtail-agent df -h / 2>/dev/null || echo "無法取得 promtail-agent 儲存資訊"
