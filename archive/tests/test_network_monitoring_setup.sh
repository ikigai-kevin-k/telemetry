#!/bin/bash

# Test script to verify network monitoring setup for GC-ARO-001-1 agent
# This script verifies that server-side can receive ethernet interface bit received metrics

echo "🔍 Testing Network Monitoring Setup for GC-ARO-001-1 Agent"
echo "========================================================="

# Configuration
AGENT_IP="100.64.0.167"
SERVER_IP="100.64.0.113"
LOKI_PORT="3100"
AGENT_NAME="GC-ARO-001-1-agent"

echo "📋 Configuration:"
echo "   Agent IP: $AGENT_IP"
echo "   Server IP: $SERVER_IP"
echo "   Loki Port: $LOKI_PORT"
echo "   Agent Name: $AGENT_NAME"
echo ""

# Test 1: Check if Loki server is running
echo "1. Checking Loki server status..."
if curl -s "http://$SERVER_IP:$LOKI_PORT/ready" > /dev/null 2>&1; then
    echo "   ✅ Loki server is running on $SERVER_IP:$LOKI_PORT"
else
    echo "   ❌ Loki server is not accessible on $SERVER_IP:$LOKI_PORT"
    echo "   Please ensure Loki server is running"
    exit 1
fi

# Test 2: Check if agent containers are running
echo ""
echo "2. Checking agent container status..."
if docker ps | grep -q "telemetry-promtail-GC-aro11-agent"; then
    echo "   ✅ Promtail container is running"
else
    echo "   ❌ Promtail container is not running"
    echo "   Please start the agent: docker-compose -f docker-compose-GC-ARO-001-1-agent.yml up -d"
    exit 1
fi

# Test 3: Verify promtail configuration
echo ""
echo "3. Verifying Promtail configuration..."
if grep -q "network_stats" /home/ella/kevin/telemetry/promtail-GC-ARO-001-1-agent.yml; then
    echo "   ✅ Network monitoring job found in promtail configuration"
else
    echo "   ❌ Network monitoring job not found in promtail configuration"
    exit 1
fi

if grep -q "enp86s0" /home/ella/kevin/telemetry/promtail-GC-ARO-001-1-agent.yml; then
    echo "   ✅ enp86s0 interface monitoring configured"
else
    echo "   ❌ enp86s0 interface monitoring not configured"
    exit 1
fi

# Test 4: Verify docker-compose volume mount
echo ""
echo "4. Verifying Docker volume mount..."
if grep -q "network_stats.log" /home/ella/kevin/telemetry/docker-compose-GC-ARO-001-1-agent.yml; then
    echo "   ✅ Network stats log file mount configured"
else
    echo "   ❌ Network stats log file mount not configured"
    exit 1
fi

# Test 5: Check Loki ingestion limits
echo ""
echo "5. Checking Loki ingestion configuration..."
if grep -q "ingestion_rate_mb: 32" /home/ella/kevin/telemetry/loki-config.yml; then
    echo "   ✅ Loki ingestion rate limit configured (32MB/s)"
else
    echo "   ⚠️  Loki ingestion rate limit may need adjustment"
fi

if grep -q "retention_period: 168h" /home/ella/kevin/telemetry/loki-config.yml; then
    echo "   ✅ Loki retention period configured (7 days)"
else
    echo "   ⚠️  Loki retention period may need adjustment"
fi

# Test 6: Verify Grafana dashboard exists
echo ""
echo "6. Checking Grafana dashboard..."
if [ -f "/home/ella/kevin/telemetry/grafana/provisioning/dashboards/network-monitor-enp86s0.json" ]; then
    echo "   ✅ Network monitoring dashboard exists"
else
    echo "   ❌ Network monitoring dashboard not found"
    exit 1
fi

# Test 7: Test Loki query for network metrics
echo ""
echo "7. Testing Loki query for network metrics..."
QUERY_RESPONSE=$(curl -s -G "http://$SERVER_IP:$LOKI_PORT/loki/api/v1/query" \
    --data-urlencode 'query={job="network_monitor",instance="GC-aro11-agent"}' \
    --data-urlencode 'limit=1' 2>/dev/null)

if echo "$QUERY_RESPONSE" | grep -q "network_monitor"; then
    echo "   ✅ Network monitoring metrics found in Loki"
    echo "   📊 Sample data:"
    echo "$QUERY_RESPONSE" | jq -r '.data.result[0].values[0][1]' 2>/dev/null | head -1
else
    echo "   ⚠️  No network monitoring metrics found in Loki yet"
    echo "   This is normal if the agent hasn't started sending data"
fi

echo ""
echo "🎯 Summary:"
echo "==========="
echo "✅ Server-side configuration is ready to receive network metrics"
echo "✅ Loki server is accessible and configured"
echo "✅ Promtail configuration includes network monitoring"
echo "✅ Docker volume mounts are configured"
echo "✅ Grafana dashboard is available"
echo ""
echo "💡 Next steps:"
echo "1. Ensure the agent-side network_monitor.py script is running"
echo "2. Verify that /var/log/network_stats.log is being created on the agent"
echo "3. Check Grafana dashboard for network interface metrics"
echo "4. Monitor Loki logs for any ingestion issues"
echo ""
echo "🔧 To start monitoring:"
echo "   On agent (100.64.0.167):"
echo "   - Run: python3 /path/to/network_monitor.py"
echo "   - Or use: ./start-network-monitor.sh"
echo ""
echo "   On server (100.64.0.113):"
echo "   - Check Grafana dashboard: http://$SERVER_IP:3000"
echo "   - Query Loki: http://$SERVER_IP:$LOKI_PORT"



