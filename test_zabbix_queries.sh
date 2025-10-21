#!/bin/bash

# Test Zabbix Queries in Grafana Format
echo "🧪 Testing Zabbix Queries in Grafana Format"
echo "==========================================="

# Get authentication token
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

if [ "$auth_token" = "null" ] || [ -z "$auth_token" ]; then
    echo "❌ Failed to get authentication token"
    exit 1
fi

echo "✅ Authentication successful"

# Test 1: Get host ID for GC-aro12-agent
echo ""
echo "1. Getting host ID for GC-aro12-agent..."
host_response=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d "{
        \"jsonrpc\": \"2.0\",
        \"method\": \"host.get\",
        \"params\": {
            \"output\": [\"hostid\", \"host\", \"name\"],
            \"filter\": {
                \"host\": [\"GC-aro12-agent\"]
            }
        },
        \"auth\": \"$auth_token\",
        \"id\": 1
    }" \
    "http://localhost:8080/api_jsonrpc.php")

host_id=$(echo "$host_response" | jq -r '.result[0].hostid' 2>/dev/null)
echo "   Host ID: $host_id"

# Test 2: Get CPU utilization item
echo ""
echo "2. Getting CPU utilization item..."
cpu_response=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d "{
        \"jsonrpc\": \"2.0\",
        \"method\": \"item.get\",
        \"params\": {
            \"output\": [\"itemid\", \"name\", \"key\", \"lastvalue\", \"lastclock\"],
            \"hostids\": [\"$host_id\"],
            \"filter\": {
                \"key\": [\"system.cpu.util\"]
            }
        },
        \"auth\": \"$auth_token\",
        \"id\": 1
    }" \
    "http://localhost:8080/api_jsonrpc.php")

cpu_item_id=$(echo "$cpu_response" | jq -r '.result[0].itemid' 2>/dev/null)
cpu_value=$(echo "$cpu_response" | jq -r '.result[0].lastvalue' 2>/dev/null)
cpu_time=$(echo "$cpu_response" | jq -r '.result[0].lastclock' 2>/dev/null)

echo "   CPU Item ID: $cpu_item_id"
echo "   CPU Value: $cpu_value"
echo "   CPU Time: $cpu_time"

# Test 3: Get Network items
echo ""
echo "3. Getting Network items..."
net_response=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d "{
        \"jsonrpc\": \"2.0\",
        \"method\": \"item.get\",
        \"params\": {
            \"output\": [\"itemid\", \"name\", \"key\", \"lastvalue\", \"lastclock\"],
            \"hostids\": [\"$host_id\"],
            \"filter\": {
                \"key\": [\"net.if.in[eth0]\", \"net.if.out[eth0]\"]
            }
        },
        \"auth\": \"$auth_token\",
        \"id\": 1
    }" \
    "http://localhost:8080/api_jsonrpc.php")

net_in_item_id=$(echo "$net_response" | jq -r '.result[] | select(.key=="net.if.in[eth0]") | .itemid' 2>/dev/null)
net_out_item_id=$(echo "$net_response" | jq -r '.result[] | select(.key=="net.if.out[eth0]") | .itemid' 2>/dev/null)

net_in_value=$(echo "$net_response" | jq -r '.result[] | select(.key=="net.if.in[eth0]") | .lastvalue' 2>/dev/null)
net_out_value=$(echo "$net_response" | jq -r '.result[] | select(.key=="net.if.out[eth0]") | .lastvalue' 2>/dev/null)

echo "   Network In Item ID: $net_in_item_id"
echo "   Network Out Item ID: $net_out_item_id"
echo "   Network In Value: $net_in_value"
echo "   Network Out Value: $net_out_value"

# Test 4: Test history data retrieval
echo ""
echo "4. Testing history data retrieval..."
history_response=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d "{
        \"jsonrpc\": \"2.0\",
        \"method\": \"history.get\",
        \"params\": {
            \"output\": \"extend\",
            \"itemids\": [\"$cpu_item_id\"],
            \"time_from\": $(date -d '1 hour ago' +%s),
            \"time_till\": $(date +%s),
            \"sortfield\": \"clock\",
            \"sortorder\": \"DESC\",
            \"limit\": 10
        },
        \"auth\": \"$auth_token\",
        \"id\": 1
    }" \
    "http://localhost:8080/api_jsonrpc.php")

history_count=$(echo "$history_response" | jq '.result | length' 2>/dev/null)
echo "   History records found: $history_count"

if [ "$history_count" -gt 0 ]; then
    echo "   Recent CPU values:"
    echo "$history_response" | jq -r '.result[] | "     \(.clock) - \(.value)"' 2>/dev/null | head -5
fi

echo ""
echo "🎯 Test Results Summary:"
echo "========================"
echo "✅ Host ID: $host_id"
echo "✅ CPU Item ID: $cpu_item_id"
echo "✅ Network In Item ID: $net_in_item_id"
echo "✅ Network Out Item ID: $net_out_item_id"
echo "✅ History Records: $history_count"
echo ""
echo "💡 These values should be used in Grafana dashboard queries:"
echo "   Host Filter: GC-aro12-agent"
echo "   CPU Item Filter: system.cpu.util"
echo "   Network In Filter: net.if.in[eth0]"
echo "   Network Out Filter: net.if.out[eth0]"
