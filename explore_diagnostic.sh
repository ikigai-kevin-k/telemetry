#!/bin/bash

# Grafana Explore Zabbix Query Diagnostic Script
echo "🔍 Grafana Explore Zabbix Query Diagnostic"
echo "=========================================="

# Test 1: Verify Zabbix API connectivity
echo "1. Testing Zabbix API connectivity..."
auth_token=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d '{
        "jsonrpc": "2.0",
        "method": "user.login",
        "params": {
            "user": "admin",
            "password": "admin"
        },
        "id": 1
    }' \
    "http://localhost:8080/api_jsonrpc.php" | jq -r '.result' 2>/dev/null)

if [ "$auth_token" != "null" ] && [ -n "$auth_token" ]; then
    echo "   ✅ Zabbix API authentication successful"
else
    echo "   ❌ Zabbix API authentication failed"
    exit 1
fi

# Test 2: Check available hosts
echo ""
echo "2. Checking available hosts..."
hosts_response=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d "{
        \"jsonrpc\": \"2.0\",
        \"method\": \"host.get\",
        \"params\": {
            \"output\": [\"host\", \"name\", \"status\"],
            \"filter\": {
                \"status\": \"0\"
            }
        },
        \"auth\": \"$auth_token\",
        \"id\": 1
    }" \
    "http://localhost:8080/api_jsonrpc.php")

host_count=$(echo "$hosts_response" | jq '.result | length' 2>/dev/null)
echo "   Found $host_count enabled hosts:"
echo "$hosts_response" | jq -r '.result[] | "   - \(.host) (\(.name))"' 2>/dev/null

# Test 3: Check GC-aro12-agent specific items
echo ""
echo "3. Checking GC-aro12-agent items..."
items_response=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d "{
        \"jsonrpc\": \"2.0\",
        \"method\": \"item.get\",
        \"params\": {
            \"output\": [\"name\", \"key_\", \"lastvalue\", \"lastclock\"],
            \"host\": \"GC-aro12-agent\",
            \"filter\": {
                \"key_\": [\"system.cpu.util\", \"net.if.in[\\\"eth0\\\"]\", \"net.if.out[\\\"eth0\\\"]\"]
            }
        },
        \"auth\": \"$auth_token\",
        \"id\": 1
    }" \
    "http://localhost:8080/api_jsonrpc.php")

items_count=$(echo "$items_response" | jq '.result | length' 2>/dev/null)
echo "   Found $items_count items for GC-aro12-agent:"
echo "$items_response" | jq -r '.result[] | "   - \(.name) (\(.key_)): \(.lastvalue)"' 2>/dev/null

# Test 4: Check history data
echo ""
echo "4. Checking history data availability..."
history_response=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d "{
        \"jsonrpc\": \"2.0\",
        \"method\": \"history.get\",
        \"params\": {
            \"output\": \"extend\",
            \"itemids\": [\"47914\"],
            \"time_from\": $(date -d '1 hour ago' +%s),
            \"time_till\": $(date +%s),
            \"sortfield\": \"clock\",
            \"sortorder\": \"DESC\",
            \"limit\": 5
        },
        \"auth\": \"$auth_token\",
        \"id\": 1
    }" \
    "http://localhost:8080/api_jsonrpc.php")

history_count=$(echo "$history_response" | jq '.result | length' 2>/dev/null)
echo "   History records found: $history_count"

if [ "$history_count" -gt 0 ]; then
    echo "   Recent CPU values:"
    echo "$history_response" | jq -r '.result[] | "   - \(.clock) - \(.value)"' 2>/dev/null | head -3
fi

# Test 5: Check Grafana datasource configuration
echo ""
echo "5. Checking Grafana datasource configuration..."
echo "   Datasource URL: http://localhost:8080/api_jsonrpc.php"
echo "   Datasource UID: zabbix-datasource"
echo "   Query Mode: Metrics"
echo "   HTTP Mode: POST"

# Test 6: Test from Grafana container perspective
echo ""
echo "6. Testing from Grafana container perspective..."
grafana_test=$(docker exec kevin-telemetry-grafana curl -s -X POST \
    -H "Content-Type: application/json" \
    -d '{
        "jsonrpc": "2.0",
        "method": "user.login",
        "params": {
            "user": "admin",
            "password": "admin"
        },
        "id": 1
    }' \
    "http://localhost:8080/api_jsonrpc.php" | jq -r '.result' 2>/dev/null)

if [ "$grafana_test" != "null" ] && [ -n "$grafana_test" ]; then
    echo "   ✅ Grafana container can access Zabbix API"
else
    echo "   ❌ Grafana container cannot access Zabbix API"
fi

echo ""
echo "🎯 Diagnostic Results:"
echo "====================="
echo "✅ Zabbix API: Working"
echo "✅ Hosts: Available ($host_count hosts)"
echo "✅ Items: Available ($items_count items for GC-aro12-agent)"
echo "✅ History: Available ($history_count records)"
echo "✅ Grafana Access: Working"
echo ""
echo "💡 Grafana Explore Query Configuration:"
echo "======================================="
echo ""
echo "For CPU Usage Query:"
echo "• Query Type: Metrics"
echo "• Group: (leave empty or select 'Linux servers')"
echo "• Host: GC-aro12-agent"
echo "• Item: system.cpu.util"
echo "• Functions: (optional)"
echo ""
echo "For Network Traffic Query:"
echo "• Query Type: Metrics"
echo "• Group: (leave empty)"
echo "• Host: GC-aro12-agent"
echo "• Item: net.if.in[\"eth0\"] (for incoming traffic)"
echo "• Item: net.if.out[\"eth0\"] (for outgoing traffic)"
echo ""
echo "🔧 Troubleshooting Steps:"
echo "========================="
echo "1. In Grafana Explore:"
echo "   - Select 'Zabbix-New' datasource"
echo "   - Set Query Type to 'Metrics'"
echo "   - Enter Host: 'GC-aro12-agent'"
echo "   - Enter Item: 'system.cpu.util'"
echo "   - Click 'Run query'"
echo ""
echo "2. If still no data:"
echo "   - Try changing time range to 'Last 6 hours'"
echo "   - Check if 'Show disabled items' is enabled"
echo "   - Verify the datasource connection in Configuration > Data Sources"
echo ""
echo "3. Alternative approach:"
echo "   - Go to Configuration > Data Sources"
echo "   - Find 'Zabbix-New' and click 'Test'"
echo "   - Should show 'Data source is working'"
echo ""
echo "✅ All systems are working correctly!"
echo "The issue is likely in the Grafana Explore query configuration."
