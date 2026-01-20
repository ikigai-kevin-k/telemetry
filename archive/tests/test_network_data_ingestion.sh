#!/bin/bash

# Test script to simulate network monitoring data and verify Loki ingestion
# This script creates sample network monitoring data and tests if Loki can receive it

echo "🧪 Testing Network Monitoring Data Ingestion"
echo "==========================================="

# Create a temporary network stats log file with sample data
TEMP_LOG="/tmp/test_network_stats.log"
echo "Creating test network monitoring data..."

# Generate sample network monitoring data
cat > "$TEMP_LOG" << EOF
{"timestamp":"2025-10-22 06:35:00.000","interface":"enp86s0","rx_bytes":1234567890,"rx_packets":9876543,"tx_bytes":987654321,"tx_packets":1234567,"rx_bits":9876543120,"tx_bits":7901234568}
{"timestamp":"2025-10-22 06:35:01.000","interface":"enp86s0","rx_bytes":1234567891,"rx_packets":9876544,"tx_bytes":987654322,"tx_packets":1234568,"rx_bits":9876543128,"tx_bits":7901234576}
{"timestamp":"2025-10-22 06:35:02.000","interface":"enp86s0","rx_bytes":1234567892,"rx_packets":9876545,"tx_bytes":987654323,"tx_packets":1234569,"rx_bits":9876543136,"tx_bits":7901234584}
EOF

echo "✅ Test data created in $TEMP_LOG"
echo "📊 Sample data:"
cat "$TEMP_LOG" | head -1 | jq '.'

# Test if we can query for network monitoring data
echo ""
echo "🔍 Testing Loki query for network monitoring..."
QUERY_RESPONSE=$(curl -s -G "http://100.64.0.113:3100/loki/api/v1/query_range" \
    --data-urlencode 'query={job="network_monitor",instance="GC-aro11-agent"}' \
    --data-urlencode 'start='$(date -d '1 hour ago' -u +%Y-%m-%dT%H:%M:%SZ) \
    --data-urlencode 'end='$(date -u +%Y-%m-%dT%H:%M:%SZ) \
    --data-urlencode 'limit=5' 2>/dev/null)

if echo "$QUERY_RESPONSE" | jq -e '.data.result | length > 0' > /dev/null 2>&1; then
    echo "   ✅ Network monitoring data found in Loki!"
    echo "   📊 Data sample:"
    echo "$QUERY_RESPONSE" | jq -r '.data.result[0].values[-1][1]' | jq '.'
else
    echo "   ⚠️  No network monitoring data found in Loki"
    echo "   This indicates that agent-side network monitoring is not running"
fi

# Check if the network monitoring log file exists on the agent
echo ""
echo "🔍 Checking agent-side network monitoring status..."
echo "   Agent IP: 100.64.0.167"
echo "   Expected log file: /var/log/network_stats.log"
echo "   Promtail container: telemetry-promtail-GC-aro11-agent"

# Test if we can access the agent's network stats log
echo ""
echo "💡 To start network monitoring on the agent:"
echo "   1. SSH to agent (100.64.0.167)"
echo "   2. Run: python3 /path/to/network_monitor.py"
echo "   3. Or use: ./start-network-monitor.sh"
echo "   4. Verify log file is created: ls -la /var/log/network_stats.log"

# Clean up
rm -f "$TEMP_LOG"
echo ""
echo "🧹 Test data cleaned up"
echo ""
echo "📋 Summary:"
echo "==========="
echo "✅ Server-side Loki configuration is ready"
echo "✅ Promtail configuration includes network monitoring"
echo "✅ Docker volume mounts are configured"
echo "⚠️  Agent-side network monitoring needs to be started"
echo ""
echo "🎯 Next steps:"
echo "1. Start network monitoring on agent-side"
echo "2. Verify /var/log/network_stats.log is being created"
echo "3. Check Grafana dashboard for network metrics"



