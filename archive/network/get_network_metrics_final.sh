#!/bin/bash

# Direct Network Interface Metrics Query for GC-ARO-001-1-agent
# This script directly queries specific network interface metrics

echo "🔍 Getting Network Interface Metrics for GC-ARO-001-1-agent"
echo "==========================================================="

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

# Step 3: Check for eth0 interface metrics
echo ""
echo "3. Checking for eth0 interface metrics..."
eth0_response=$(make_api_call "item.get" "{
    \"output\": [\"itemid\", \"name\", \"key\", \"lastvalue\", \"lastclock\", \"units\"],
    \"hostids\": [\"$host_id\"],
    \"filter\": {
        \"key\": [\"net.if.in[eth0]\", \"net.if.out[eth0]\", \"net.if.speed[eth0]\", \"net.if.status[eth0]\"]
    }
}")

eth0_count=$(echo "$eth0_response" | jq '.result | length' 2>/dev/null)

if [ "$eth0_count" -gt 0 ]; then
    echo "   ✅ Found eth0 interface metrics:"
    echo "$eth0_response" | jq -r '.result[] | "     \(.name) (\(.key)): \(.lastvalue) \(.units // "")"' 2>/dev/null
else
    echo "   ❌ eth0 interface not found"
fi

# Step 4: Check for enp86s0 interface metrics
echo ""
echo "4. Checking for enp86s0 interface metrics..."
enp86s0_response=$(make_api_call "item.get" "{
    \"output\": [\"itemid\", \"name\", \"key\", \"lastvalue\", \"lastclock\", \"units\"],
    \"hostids\": [\"$host_id\"],
    \"filter\": {
        \"key\": [\"net.if.in[enp86s0]\", \"net.if.out[enp86s0]\", \"net.if.speed[enp86s0]\", \"net.if.status[enp86s0]\"]
    }
}")

enp86s0_count=$(echo "$enp86s0_response" | jq '.result | length' 2>/dev/null)

if [ "$enp86s0_count" -gt 0 ]; then
    echo "   ✅ Found enp86s0 interface metrics:"
    echo "$enp86s0_response" | jq -r '.result[] | "     \(.name) (\(.key)): \(.lastvalue) \(.units // "")"' 2>/dev/null
else
    echo "   ❌ enp86s0 interface not found"
fi

# Step 5: Get all network interface items to see what's available
echo ""
echo "5. Getting all network interface items..."
all_network_response=$(make_api_call "item.get" "{
    \"output\": [\"itemid\", \"name\", \"key\", \"lastvalue\", \"lastclock\", \"units\"],
    \"hostids\": [\"$host_id\"],
    \"search\": {
        \"key\": \"net.if\"
    }
}")

all_network_count=$(echo "$all_network_response" | jq '.result | length' 2>/dev/null)

if [ "$all_network_count" -gt 0 ]; then
    echo "   ✅ Found $all_network_count network interface items:"
    echo "$all_network_response" | jq -r '.result[] | select(.key | test("net\\.if\\.[^[]*\\[[^]]*\\]")) | "     \(.name) (\(.key)): \(.lastvalue) \(.units // "")"' 2>/dev/null
else
    echo "   ❌ No network interface items found"
fi

# Step 6: Generate Grafana query format
echo ""
echo "6. Grafana Query Format:"
echo "========================"
echo "For use in Grafana Zabbix datasource:"
echo ""
echo "Host Filter: $HOST_NAME"
echo ""

if [ "$eth0_count" -gt 0 ]; then
    echo "Available Item Filters for eth0:"
    echo "- Network In (eth0):  net.if.in[eth0]"
    echo "- Network Out (eth0): net.if.out[eth0]"
    echo "- Network Speed (eth0): net.if.speed[eth0]"
    echo "- Network Status (eth0): net.if.status[eth0]"
    echo ""
fi

if [ "$enp86s0_count" -gt 0 ]; then
    echo "Available Item Filters for enp86s0:"
    echo "- Network In (enp86s0):  net.if.in[enp86s0]"
    echo "- Network Out (enp86s0): net.if.out[enp86s0]"
    echo "- Network Speed (enp86s0): net.if.speed[enp86s0]"
    echo "- Network Status (enp86s0): net.if.status[enp86s0]"
    echo ""
fi

echo "Example Grafana Panel Query:"
if [ "$eth0_count" -gt 0 ]; then
    echo "Host: $HOST_NAME"
    echo "Item: net.if.in[eth0]"
    echo "Function: avg"
    echo "Time Range: Last 1 hour"
elif [ "$enp86s0_count" -gt 0 ]; then
    echo "Host: $HOST_NAME"
    echo "Item: net.if.in[enp86s0]"
    echo "Function: avg"
    echo "Time Range: Last 1 hour"
else
    echo "No network interface metrics available"
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
echo "✅ Total Network Items: $all_network_count"
if [ "$eth0_count" -gt 0 ]; then
    echo "✅ eth0 Interface: Available ($eth0_count items)"
else
    echo "❌ eth0 Interface: Not found"
fi
if [ "$enp86s0_count" -gt 0 ]; then
    echo "✅ enp86s0 Interface: Available ($enp86s0_count items)"
else
    echo "❌ enp86s0 Interface: Not found"
fi
echo ""
echo "💡 Next steps:"
echo "1. Use the Grafana query format above in your dashboard"
echo "2. Configure time range and refresh interval as needed"
echo "3. Add alerts based on network traffic thresholds"
if [ "$eth0_count" -gt 0 ]; then
    echo "4. Use eth0 interface metrics as it's available on this host"
fi
if [ "$enp86s0_count" -gt 0 ]; then
    echo "5. Use enp86s0 interface metrics as it's available on this host"
fi