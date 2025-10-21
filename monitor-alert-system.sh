#!/bin/bash

# Monitor Alert System - Real-time monitoring of alert flow
# This script helps you see the entire flow from log detection to API call

echo "=================================================="
echo "Alert System Monitoring Dashboard"
echo "=================================================="
echo ""
echo "監控內容："
echo "1. Grafana Alert 評估"
echo "2. Webhook 接收"
echo "3. API 請求發送"
echo ""
echo "按 Ctrl+C 停止監控"
echo "=================================================="
echo ""

# Function to display in color
print_header() {
    echo -e "\n\033[1;36m========== $1 ==========\033[0m"
}

print_success() {
    echo -e "\033[1;32m✓ $1\033[0m"
}

print_error() {
    echo -e "\033[1;31m✗ $1\033[0m"
}

print_info() {
    echo -e "\033[1;33m→ $1\033[0m"
}

# Check services status
print_header "服務狀態檢查"

# Check webhook service
if ps aux | grep -q "[g]rafana_webhook_service.py"; then
    WEBHOOK_PID=$(ps aux | grep "[g]rafana_webhook_service.py" | awk '{print $2}')
    print_success "Webhook 服務運行中 (PID: $WEBHOOK_PID)"
else
    print_error "Webhook 服務未運行！請執行 ./start-webhook-service.sh"
fi

# Check Grafana
if docker ps | grep -q "kevin-telemetry-grafana"; then
    print_success "Grafana 容器運行中"
else
    print_error "Grafana 容器未運行！"
fi

# Check test agent
if docker ps | grep -q "telemetry-promtail-test-agent"; then
    print_success "Test Agent 運行中"
else
    print_error "Test Agent 未運行！請執行 ./start-test-agent.sh tpe"
fi

print_header "查詢最近 3 小時的 okbps=0,0,0 日誌"

# Query Loki for okbps logs
LOKI_COUNT=$(curl -s -G 'http://100.64.0.160:3100/loki/api/v1/query_range' \
  --data-urlencode 'query={job="srs_test", instance="telemetry-promtail-test-agent"} |= "okbps=0,0,0"' \
  --data-urlencode 'limit=1000' \
  --data-urlencode "start=$(date -d '3 hours ago' +%s)000000000" \
  --data-urlencode "end=$(date +%s)000000000" 2>/dev/null | \
  python3 -c "import sys, json; data=json.load(sys.stdin); print(sum(len(stream.get('values', [])) for stream in data.get('data', {}).get('result', [])))" 2>/dev/null)

if [ ! -z "$LOKI_COUNT" ] && [ "$LOKI_COUNT" -gt 0 ]; then
    print_success "Loki 中找到 $LOKI_COUNT 條包含 okbps=0,0,0 的日誌"
    print_info "這些日誌應該會觸發 Grafana Alert"
else
    print_info "Loki 中未找到 okbps=0,0,0 日誌"
    echo ""
    echo "要產生測試日誌，執行："
    echo "  echo \"[$(date '+%Y-%m-%d %H:%M:%S')][INFO][test] <- CPB time=123456, okbps=0,0,0, ikbps=0,0,0\" >> /home/ella/share_folder/srs.log"
fi

print_header "開始實時監控（最近 30 秒）"

# Start monitoring in background
{
    while true; do
        clear
        echo "=================================================="
        echo "實時監控 - $(date '+%Y-%m-%d %H:%M:%S')"
        echo "=================================================="
        
        echo ""
        print_header "1. Grafana Alert 活動"
        echo "（查找包含 'srs-okbps-zero-alert' 的日誌）"
        docker logs kevin-telemetry-grafana --since 30s 2>&1 | \
            grep -i "srs-okbps-zero-alert" | tail -5 || echo "   暫無 alert 活動"
        
        echo ""
        print_header "2. Webhook 接收記錄"
        echo "（最近 30 秒內收到的 webhook）"
        tail -n 50 /home/ella/kevin/telemetry/webhook_service.log | \
            grep -A 3 "Received Grafana alert" | tail -10 || echo "   暫無 webhook 接收"
        
        echo ""
        print_header "3. API 請求發送記錄"
        echo "（發送到 100.64.0.160:8085 的請求）"
        tail -n 50 /home/ella/kevin/telemetry/webhook_service.log | \
            grep -E "(Sending API request|API Response)" | tail -10 || echo "   暫無 API 請求"
        
        echo ""
        echo "=================================================="
        echo "刷新間隔: 5 秒 | 按 Ctrl+C 停止"
        echo "=================================================="
        
        sleep 5
    done
}

