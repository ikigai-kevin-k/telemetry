#!/bin/bash

# Get All Network Interface Metrics for GC-ARO-001-1-agent via Zabbix API
# This script retrieves all network interface metrics for GC-ARO-001-1-agent

echo "🔍 Getting All Network Interface Metrics for GC-ARO-001-1-agent"
echo "==============================================================="

# Configuration
ZABBIX_URL="http://localhost:8080/api_jsonrpc.php"
ZABBIX_USER="admin"
ZABBIX_PASSWORD="admin"
HOST_NAME="GC-ARO-001-1-agent"

# Function to make API calls
make_api_call() {
    local method="$1"
    local params="$2"
    
    curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "{
            \"jsonrpc\": \"2.0\",
            \"method\": \"$method\",
            \"params\": $params,
            \"auth\": \"$auth_token\",
            \"id\": 1
        }" \
        "$ZABBIX_URL"
}

# Step 1: Authenticate with Zabbix API
echo "1. Authenticating with Zabbix API..."
auth_response=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d "{
        \"jsonrpc\": \"2.0\",
        \"method\": \"user.login\",
        \"params\": {
            \"user\": \"$ZABBIX_USER\",
            \"password\": \"$ZABBIX_PASSWORD\"
        },
        \"id\": 1
    }" \
    "$ZABBIX_URL")

auth_token=$(echo "$auth_response" | jq -r '.result' 2>/dev/null)

if [ "$auth_token" = "null" ] || [ -z "$auth_token" ]; then
    echo "   ❌ Authentication failed"
    echo "   Response: $auth_response"
    exit 1
fi

echo "   ✅ Authentication successful"
echo "   Token: ${auth_token:0:20}..."

# Step 2: Get host information
echo ""
echo "2. Getting host information for $HOST_NAME..."
host_response=$(make_api_call "host.get" "{
    \"output\": [\"hostid\", \"host\", \"name\", \"status\", \"available\"],
    \"filter\": {
        \"host\": [\"$HOST_NAME\"]
    }
}")

host_count=$(echo "$host_response" | jq '.result | length' 2>/dev/null)

if [ "$host_count" -eq 0 ]; then
    echo "   ❌ Host $HOST_NAME not found in Zabbix"
    echo "   Response: $host_response"
    exit 1
fi

host_id=$(echo "$host_response" | jq -r '.result[0].hostid' 2>/dev/null)
host_status=$(echo "$host_response" | jq -r '.result[0].status' 2>/dev/null)
host_available=$(echo "$host_response" | jq -r '.result[0].available' 2>/dev/null)

echo "   ✅ Host found:"
echo "   Host ID: $host_id"
echo "   Status: $host_status (0=enabled, 1=disabled)"
echo "   Available: $host_available (1=available, 2=unavailable)"

# Step 3: Get all network interface items
echo ""
echo "3. Getting all network interface items..."
network_response=$(make_api_call "item.get" "{
    \"output\": [\"itemid\", \"name\", \"key\", \"lastvalue\", \"lastclock\", \"units\", \"status\"],
    \"hostids\": [\"$host_id\"],
    \"search\": {
        \"key\": \"net.if\"
    }
}")

network_items_count=$(echo "$network_response" | jq '.result | length' 2>/dev/null)

if [ "$network_items_count" -eq 0 ]; then
    echo "   ❌ No network interface items found"
    echo "   Response: $network_response"
    exit 1
fi

echo "   ✅ Found $network_items_count network interface items:"

# Parse and display all network interface metrics
echo ""
echo "   📋 All Network Interface Items:"
echo "$network_response" | jq -r '.result[] | "     - \(.name) (\(.key)): \(.lastvalue) \(.units // "")"' 2>/dev/null

# Extract unique interface names
echo ""
echo "   🔍 Available Network Interfaces:"
interfaces=$(echo "$network_response" | jq -r '.result[] | .key' 2>/dev/null | grep -o 'net\.if\.[^[]*\[[^]]*\]' | sed 's/net\.if\.[^[]*\[\([^]]*\)\]/\1/' | sort -u)

for interface in $interfaces; do
    echo "     - $interface"
done

# Step 4: Get detailed metrics for each interface
echo ""
echo "4. Detailed metrics for each interface:"

for interface in $interfaces; do
    echo ""
    echo "   🌐 Interface: $interface"
    echo "   ========================="
    
    # Get metrics for this specific interface
    interface_response=$(make_api_call "item.get" "{
        \"output\": [\"itemid\", \"name\", \"key\", \"lastvalue\", \"lastclock\", \"units\"],
        \"hostids\": [\"$host_id\"],
        \"filter\": {
            \"key\": [\"net.if.in[$interface]\", \"net.if.out[$interface]\", \"net.if.total[$interface]\", \"net.if.speed[$interface]\", \"net.if.status[$interface]\"]
        }
    }")
    
    interface_items_count=$(echo "$interface_response" | jq '.result | length' 2>/dev/null)
    
    if [ "$interface_items_count" -gt 0 ]; then
        echo "$interface_response" | jq -r '.result[] | "     \(.name) (\(.key)): \(.lastvalue) \(.units // "")"' 2>/dev/null
    else
        echo "     No specific metrics found for $interface"
    fi
done

# Step 5: Generate Grafana query format
echo ""
echo "5. Grafana Query Format:"
echo "========================"
echo "For use in Grafana Zabbix datasource:"
echo ""
echo "Host Filter: $HOST_NAME"
echo ""
echo "Available Item Filters:"

for interface in $interfaces; do
    echo "- Network In ($interface):  net.if.in[$interface]"
    echo "- Network Out ($interface): net.if.out[$interface]"
    echo "- Network Total ($interface): net.if.total[$interface]"
    echo "- Network Speed ($interface): net.if.speed[$interface]"
    echo "- Network Status ($interface): net.if.status[$interface]"
    echo ""
done

# Step 6: Get historical data for the most active interface
echo ""
echo "6. Getting historical data for the most active interface..."

# Find the interface with the highest traffic
most_active_interface=""
highest_traffic=0

for interface in $interfaces; do
    interface_response=$(make_api_call "item.get" "{
        \"output\": [\"key\", \"lastvalue\"],
        \"hostids\": [\"$host_id\"],
        \"filter\": {
            \"key\": [\"net.if.in[$interface]\", \"net.if.out[$interface]\"]
        }
    }")
    
    in_traffic=$(echo "$interface_response" | jq -r '.result[] | select(.key=="net.if.in['$interface']") | .lastvalue' 2>/dev/null)
    out_traffic=$(echo "$interface_response" | jq -r '.result[] | select(.key=="net.if.out['$interface']") | .lastvalue' 2>/dev/null)
    
    if [ "$in_traffic" != "null" ] && [ -n "$in_traffic" ] && [ "$out_traffic" != "null" ] && [ -n "$out_traffic" ]; then
        total_traffic=$((in_traffic + out_traffic))
        if [ "$total_traffic" -gt "$highest_traffic" ]; then
            highest_traffic=$total_traffic
            most_active_interface=$interface
        fi
    fi
done

if [ -n "$most_active_interface" ]; then
    echo "   Most active interface: $most_active_interface"
    
    # Get item ID for historical data
    active_interface_response=$(make_api_call "item.get" "{
        \"output\": [\"itemid\", \"key\"],
        \"hostids\": [\"$host_id\"],
        \"filter\": {
            \"key\": [\"net.if.in[$most_active_interface]\"]
        }
    }")
    
    active_item_id=$(echo "$active_interface_response" | jq -r '.result[0].itemid' 2>/dev/null)
    
    if [ "$active_item_id" != "null" ] && [ -n "$active_item_id" ]; then
        history_response=$(make_api_call "history.get" "{
            \"output\": [\"clock\", \"value\"],
            \"itemids\": [\"$active_item_id\"],
            \"time_from\": $(date -d '1 hour ago' +%s),
            \"time_till\": $(date +%s),
            \"sortfield\": \"clock\",
            \"sortorder\": \"DESC\",
            \"limit\": 10
        }")
        
        history_count=$(echo "$history_response" | jq '.result | length' 2>/dev/null)
        echo "   📈 Historical data for net.if.in[$most_active_interface] (last 10 records):"
        
        if [ "$history_count" -gt 0 ]; then
            echo "$history_response" | jq -r '.result[] | "     \(.clock) - \(.value)"' 2>/dev/null
        else
            echo "     No historical data found"
        fi
    fi
else
    echo "   No active interface found for historical data"
fi

# Step 7: Logout
echo ""
echo "7. Logging out from Zabbix API..."
logout_response=$(make_api_call "user.logout" "[]")
echo "   ✅ Logged out successfully"

echo ""
echo "🎯 Summary:"
echo "==========="
echo "✅ Host: $HOST_NAME (ID: $host_id)"
echo "✅ Network Interfaces Found: $(echo $interfaces | wc -w)"
echo "✅ Total Network Items: $network_items_count"
if [ -n "$most_active_interface" ]; then
    echo "✅ Most Active Interface: $most_active_interface"
fi
echo ""
echo "💡 Next steps:"
echo "1. Use the Grafana query format above in your dashboard"
echo "2. Configure time range and refresh interval as needed"
echo "3. Add alerts based on network traffic thresholds"
echo "4. Monitor the most active interface: $most_active_interface"



