#!/bin/bash

# Get GC-ARO-001-1-agent Network Interface Metrics via Zabbix API
# This script retrieves net.if.in["enp86s0"] metrics for GC-ARO-001-1-agent

echo "🔍 Getting GC-ARO-001-1-agent Network Interface Metrics"
echo "======================================================"

# Configuration
ZABBIX_URL="http://localhost:8080/api_jsonrpc.php"
ZABBIX_USER="admin"
ZABBIX_PASSWORD="admin"
HOST_NAME="GC-ARO-001-1-agent"
INTERFACE_NAME="enp86s0"

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

# Step 3: Get network interface items
echo ""
echo "3. Getting network interface items for $INTERFACE_NAME..."
network_response=$(make_api_call "item.get" "{
    \"output\": [\"itemid\", \"name\", \"key\", \"lastvalue\", \"lastclock\", \"units\", \"status\"],
    \"hostids\": [\"$host_id\"],
    \"filter\": {
        \"key\": [\"net.if.in[$INTERFACE_NAME]\", \"net.if.out[$INTERFACE_NAME]\", \"net.if.total[$INTERFACE_NAME]\"]
    }
}")

network_items_count=$(echo "$network_response" | jq '.result | length' 2>/dev/null)

if [ "$network_items_count" -eq 0 ]; then
    echo "   ❌ No network interface items found for $INTERFACE_NAME"
    echo "   Response: $network_response"
    
    # Try to find all network interface items for this host
    echo ""
    echo "   🔍 Searching for all network interface items on this host..."
    all_network_response=$(make_api_call "item.get" "{
        \"output\": [\"name\", \"key\", \"lastvalue\"],
        \"hostids\": [\"$host_id\"],
        \"search\": {
            \"key\": \"net.if\"
        }
    }")
    
    all_network_count=$(echo "$all_network_response" | jq '.result | length' 2>/dev/null)
    echo "   Found $all_network_count network interface items:"
    echo "$all_network_response" | jq -r '.result[] | "     - \(.name) (\(.key)): \(.lastvalue)"' 2>/dev/null
    exit 1
fi

echo "   ✅ Found $network_items_count network interface items:"

# Parse and display network interface metrics
echo "   📋 All network interface items found:"
echo "$network_response" | jq -r '.result[] | "     - \(.name) (\(.key)): \(.lastvalue) \(.units // "")"' 2>/dev/null

# Look for specific interface metrics
net_in_item=$(echo "$network_response" | jq -r '.result[] | select(.key=="net.if.in['$INTERFACE_NAME']")' 2>/dev/null)
net_out_item=$(echo "$network_response" | jq -r '.result[] | select(.key=="net.if.out['$INTERFACE_NAME']")' 2>/dev/null)
net_total_item=$(echo "$network_response" | jq -r '.result[] | select(.key=="net.if.total['$INTERFACE_NAME']")' 2>/dev/null)

echo ""
echo "   🎯 Specific metrics for $INTERFACE_NAME:"

if [ "$net_in_item" != "null" ] && [ -n "$net_in_item" ]; then
    net_in_itemid=$(echo "$net_in_item" | jq -r '.itemid')
    net_in_value=$(echo "$net_in_item" | jq -r '.lastvalue')
    net_in_time=$(echo "$net_in_item" | jq -r '.lastclock')
    net_in_units=$(echo "$net_in_item" | jq -r '.units')
    
    echo "   📥 Network In ($INTERFACE_NAME):"
    echo "     Item ID: $net_in_itemid"
    echo "     Value: $net_in_value $net_in_units"
    echo "     Last Update: $(date -d @$net_in_time 2>/dev/null || echo $net_in_time)"
else
    echo "   ❌ Network In ($INTERFACE_NAME): Not found"
fi

if [ "$net_out_item" != "null" ] && [ -n "$net_out_item" ]; then
    net_out_itemid=$(echo "$net_out_item" | jq -r '.itemid')
    net_out_value=$(echo "$net_out_item" | jq -r '.lastvalue')
    net_out_time=$(echo "$net_out_item" | jq -r '.lastclock')
    net_out_units=$(echo "$net_out_item" | jq -r '.units')
    
    echo "   📤 Network Out ($INTERFACE_NAME):"
    echo "     Item ID: $net_out_itemid"
    echo "     Value: $net_out_value $net_out_units"
    echo "     Last Update: $(date -d @$net_out_time 2>/dev/null || echo $net_out_time)"
else
    echo "   ❌ Network Out ($INTERFACE_NAME): Not found"
fi

if [ "$net_total_item" != "null" ] && [ -n "$net_total_item" ]; then
    net_total_itemid=$(echo "$net_total_item" | jq -r '.itemid')
    net_total_value=$(echo "$net_total_item" | jq -r '.lastvalue')
    net_total_time=$(echo "$net_total_item" | jq -r '.lastclock')
    net_total_units=$(echo "$net_total_item" | jq -r '.units')
    
    echo "   📊 Network Total ($INTERFACE_NAME):"
    echo "     Item ID: $net_total_itemid"
    echo "     Value: $net_total_value $net_total_units"
    echo "     Last Update: $(date -d @$net_total_time 2>/dev/null || echo $net_total_time)"
else
    echo "   ❌ Network Total ($INTERFACE_NAME): Not found"
fi

# Step 4: Get historical data for the last hour
echo ""
echo "4. Getting historical data for the last hour..."

if [ "$net_in_item" != "null" ] && [ -n "$net_in_item" ]; then
    net_in_itemid=$(echo "$net_in_item" | jq -r '.itemid')
    
    history_response=$(make_api_call "history.get" "{
        \"output\": [\"clock\", \"value\"],
        \"itemids\": [\"$net_in_itemid\"],
        \"time_from\": $(date -d '1 hour ago' +%s),
        \"time_till\": $(date +%s),
        \"sortfield\": \"clock\",
        \"sortorder\": \"DESC\",
        \"limit\": 10
    }")
    
    history_count=$(echo "$history_response" | jq '.result | length' 2>/dev/null)
    echo "   📈 Historical data for net.if.in[$INTERFACE_NAME] (last 10 records):"
    
    if [ "$history_count" -gt 0 ]; then
        echo "$history_response" | jq -r '.result[] | "     \(.clock) - \(.value)"' 2>/dev/null
    else
        echo "     No historical data found"
    fi
fi

# Step 5: Generate Grafana query format
echo ""
echo "5. Grafana Query Format:"
echo "========================"
echo "For use in Grafana Zabbix datasource:"
echo ""
echo "Host Filter: $HOST_NAME"
echo "Item Filter: net.if.in[$INTERFACE_NAME]"
echo ""
echo "Or use these specific queries:"
echo "- Network In:  Host: $HOST_NAME, Item: net.if.in[$INTERFACE_NAME]"
echo "- Network Out: Host: $HOST_NAME, Item: net.if.out[$INTERFACE_NAME]"
echo "- Network Total: Host: $HOST_NAME, Item: net.if.total[$INTERFACE_NAME]"

# Step 6: Logout
echo ""
echo "6. Logging out from Zabbix API..."
logout_response=$(make_api_call "user.logout" "[]")
echo "   ✅ Logged out successfully"

echo ""
echo "🎯 Summary:"
echo "==========="
echo "✅ Host: $HOST_NAME (ID: $host_id)"
echo "✅ Interface: $INTERFACE_NAME"
if [ "$net_in_item" != "null" ] && [ -n "$net_in_item" ]; then
    echo "✅ Network In Metrics: Available"
fi
if [ "$net_out_item" != "null" ] && [ -n "$net_out_item" ]; then
    echo "✅ Network Out Metrics: Available"
fi
if [ "$net_total_item" != "null" ] && [ -n "$net_total_item" ]; then
    echo "✅ Network Total Metrics: Available"
fi
echo ""
echo "💡 Next steps:"
echo "1. Use the Grafana query format above in your dashboard"
echo "2. Configure time range and refresh interval as needed"
echo "3. Add alerts based on network traffic thresholds"
