#!/bin/bash

# Verify ARO-002-1 Agent Data in Zabbix via API
# This script checks if GC-ARO-002-1-agent data is available in Zabbix Server

set -euo pipefail

# Configuration
ZABBIX_URL="${ZABBIX_URL:-http://100.64.0.113:8080/api_jsonrpc.php}"
ZABBIX_USER="${ZABBIX_USER:-admin}"
ZABBIX_PASSWORD="${ZABBIX_PASSWORD:-admin}"
HOST_NAME="GC-ARO-002-1-agent"
NETWORK_INTERFACE="eth0"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "🔍 Verifying ARO-002-1 Agent Data in Zabbix"
echo "============================================"
echo ""
echo "Configuration:"
echo "  Zabbix URL: $ZABBIX_URL"
echo "  Host Name: $HOST_NAME"
echo "  Network Interface: $NETWORK_INTERFACE"
echo ""

# Function to make API call
zabbix_api_call() {
    local method="$1"
    local params="$2"
    local auth_token="$3"
    
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

# Step 1: Authenticate
echo -e "${BLUE}Step 1: Authenticating with Zabbix API...${NC}"
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
error_msg=$(echo "$auth_response" | jq -r '.error.message // empty' 2>/dev/null)

if [ "$auth_token" = "null" ] || [ -z "$auth_token" ] || [ "$auth_token" = "" ]; then
    echo -e "${RED}❌ Authentication failed${NC}"
    if [ -n "$error_msg" ]; then
        echo -e "${RED}   Error: $error_msg${NC}"
    fi
    echo "   Response: $auth_response"
    exit 1
fi

echo -e "${GREEN}✅ Authentication successful${NC}"
echo "   Token: ${auth_token:0:20}..."
echo ""

# Step 2: Check if host exists
echo -e "${BLUE}Step 2: Checking if host exists...${NC}"
host_response=$(zabbix_api_call "host.get" "{
    \"output\": [\"hostid\", \"host\", \"name\", \"status\", \"available\"],
    \"filter\": {
        \"host\": [\"$HOST_NAME\"]
    }
}" "$auth_token")

host_count=$(echo "$host_response" | jq '.result | length' 2>/dev/null)
host_error=$(echo "$host_response" | jq -r '.error.message // empty' 2>/dev/null)

if [ "$host_count" -eq 0 ]; then
    echo -e "${RED}❌ Host '$HOST_NAME' not found in Zabbix${NC}"
    if [ -n "$host_error" ]; then
        echo -e "${RED}   Error: $host_error${NC}"
    fi
    echo "   Response: $host_response"
    exit 1
fi

host_id=$(echo "$host_response" | jq -r '.result[0].hostid' 2>/dev/null)
host_status=$(echo "$host_response" | jq -r '.result[0].status' 2>/dev/null)
host_available=$(echo "$host_response" | jq -r '.result[0].available' 2>/dev/null)

echo -e "${GREEN}✅ Host found${NC}"
echo "   Host ID: $host_id"
echo "   Status: $host_status (0=enabled, 1=disabled)"
echo "   Available: $host_available (1=available, 2=unavailable, 3=unknown)"

if [ "$host_available" != "1" ]; then
    echo -e "${YELLOW}⚠️  Warning: Host is not available (status: $host_available)${NC}"
    echo "   This may indicate the agent is not connected to the server"
fi
echo ""

# Step 3: Get network traffic items
echo -e "${BLUE}Step 3: Checking network traffic items...${NC}"

# Get all items for this host to see what's available
all_items_response=$(zabbix_api_call "item.get" "{
    \"output\": [\"itemid\", \"name\", \"key_\", \"lastvalue\", \"lastclock\", \"state\", \"status\"],
    \"hostids\": [\"$host_id\"]
}" "$auth_token")

# Filter for network interface items using jq
items_response=$(echo "$all_items_response" | jq '{
    result: [.result[] | select(
        (.key_ | ascii_downcase | contains("net.if")) or 
        (.key_ | ascii_downcase | contains("network")) or 
        (.name | ascii_downcase | contains("interface")) or 
        (.name | ascii_downcase | contains("network"))
    )]
}' 2>/dev/null || echo '{"result":[]}')

items_count=$(echo "$items_response" | jq '.result | length' 2>/dev/null || echo "0")

if [ "$items_count" -eq 0 ]; then
    echo -e "${YELLOW}⚠️  No network interface items found${NC}"
    echo "   Showing all available items for this host..."
    all_items_count=$(echo "$all_items_response" | jq '.result | length' 2>/dev/null)
    echo "   Total items: $all_items_count"
    echo "   Sample items (first 10):"
    echo "$all_items_response" | jq -r '.result[0:10][] | "     - \(.name) (\(.key_))"' 2>/dev/null
fi

if [ "$items_count" -gt 0 ]; then
    echo -e "${GREEN}✅ Found $items_count network interface item(s)${NC}"
    echo ""
    echo "Network Traffic Items:"
    echo "$items_response" | jq -r '.result[] | "  - \(.name) (\(.key_))"' 2>/dev/null
    echo ""
    
    # Check for specific items
    net_in_item=$(echo "$items_response" | jq -r ".result[] | select(.key_ | contains(\"in\") or contains(\"received\")) | .itemid" 2>/dev/null | head -1)
    net_out_item=$(echo "$items_response" | jq -r ".result[] | select(.key_ | contains(\"out\") or contains(\"sent\")) | .itemid" 2>/dev/null | head -1)
    
    if [ -n "$net_in_item" ] && [ "$net_in_item" != "null" ]; then
        net_in_value=$(echo "$items_response" | jq -r ".result[] | select(.itemid==\"$net_in_item\") | .lastvalue" 2>/dev/null)
        net_in_time=$(echo "$items_response" | jq -r ".result[] | select(.itemid==\"$net_in_item\") | .lastclock" 2>/dev/null)
        net_in_state=$(echo "$items_response" | jq -r ".result[] | select(.itemid==\"$net_in_item\") | .state" 2>/dev/null)
        
        echo -e "${BLUE}Network In (RX) Item:${NC}"
        echo "   Item ID: $net_in_item"
        echo "   Last Value: $net_in_value"
        if [ -n "$net_in_time" ] && [ "$net_in_time" != "0" ] && [ "$net_in_time" != "null" ]; then
            net_in_date=$(date -d "@$net_in_time" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "Invalid timestamp")
            echo "   Last Update: $net_in_date (${net_in_time}s ago)"
            
            # Check if data is recent (within last 10 minutes)
            current_time=$(date +%s)
            time_diff=$((current_time - net_in_time))
            if [ "$time_diff" -lt 600 ]; then
                echo -e "   ${GREEN}✅ Data is recent (${time_diff}s ago)${NC}"
            else
                echo -e "   ${YELLOW}⚠️  Data is old (${time_diff}s ago, more than 10 minutes)${NC}"
            fi
        else
            echo -e "   ${RED}❌ No timestamp available${NC}"
        fi
        echo "   State: $net_in_state (0=normal, 1=not supported)"
        echo ""
    fi
    
    if [ -n "$net_out_item" ] && [ "$net_out_item" != "null" ]; then
        net_out_value=$(echo "$items_response" | jq -r ".result[] | select(.itemid==\"$net_out_item\") | .lastvalue" 2>/dev/null)
        net_out_time=$(echo "$items_response" | jq -r ".result[] | select(.itemid==\"$net_out_item\") | .lastclock" 2>/dev/null)
        net_out_state=$(echo "$items_response" | jq -r ".result[] | select(.itemid==\"$net_out_item\") | .state" 2>/dev/null)
        
        echo -e "${BLUE}Network Out (TX) Item:${NC}"
        echo "   Item ID: $net_out_item"
        echo "   Last Value: $net_out_value"
        if [ -n "$net_out_time" ] && [ "$net_out_time" != "0" ] && [ "$net_out_time" != "null" ]; then
            net_out_date=$(date -d "@$net_out_time" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "Invalid timestamp")
            echo "   Last Update: $net_out_date (${net_out_time}s ago)"
            
            # Check if data is recent
            current_time=$(date +%s)
            time_diff=$((current_time - net_out_time))
            if [ "$time_diff" -lt 600 ]; then
                echo -e "   ${GREEN}✅ Data is recent (${time_diff}s ago)${NC}"
            else
                echo -e "   ${YELLOW}⚠️  Data is old (${time_diff}s ago, more than 10 minutes)${NC}"
            fi
        else
            echo -e "   ${RED}❌ No timestamp available${NC}"
        fi
        echo "   State: $net_out_state (0=normal, 1=not supported)"
        echo ""
    fi
else
    echo -e "${RED}❌ No network interface items found${NC}"
    echo "   Response: $items_response"
fi

# Step 4: Get history data (last hour)
if [ -n "$net_in_item" ] && [ "$net_in_item" != "null" ]; then
    echo -e "${BLUE}Step 4: Checking history data (last hour)...${NC}"
    
    time_from=$(date -d '1 hour ago' +%s)
    time_till=$(date +%s)
    
    history_response=$(zabbix_api_call "history.get" "{
        \"output\": \"extend\",
        \"itemids\": [\"$net_in_item\"],
        \"time_from\": $time_from,
        \"time_till\": $time_till,
        \"sortfield\": \"clock\",
        \"sortorder\": \"DESC\",
        \"limit\": 10
    }" "$auth_token")
    
    history_count=$(echo "$history_response" | jq '.result | length' 2>/dev/null)
    
    if [ "$history_count" -gt 0 ]; then
        echo -e "${GREEN}✅ Found $history_count history records in the last hour${NC}"
        echo ""
        echo "Recent values (last 5):"
        echo "$history_response" | jq -r '.result[0:5][] | "  - \(.clock | tonumber | strftime("%Y-%m-%d %H:%M:%S")): \(.value)"' 2>/dev/null
    else
        echo -e "${YELLOW}⚠️  No history data found in the last hour${NC}"
        echo "   This may indicate data is not being collected or stored"
    fi
    echo ""
fi

# Step 5: Summary
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Summary${NC}"
echo -e "${BLUE}========================================${NC}"

if [ "$host_available" = "1" ]; then
    echo -e "${GREEN}✅ Host Status: Available${NC}"
else
    echo -e "${RED}❌ Host Status: Not Available${NC}"
fi

if [ "$items_count" -gt 0 ]; then
    echo -e "${GREEN}✅ Network Items: Found ($items_count items)${NC}"
else
    echo -e "${RED}❌ Network Items: Not Found${NC}"
fi

if [ -n "$net_in_item" ] && [ "$net_in_item" != "null" ]; then
    if [ -n "$net_in_time" ] && [ "$net_in_time" != "0" ] && [ "$net_in_time" != "null" ]; then
        current_time=$(date +%s)
        time_diff=$((current_time - net_in_time))
        if [ "$time_diff" -lt 600 ]; then
            echo -e "${GREEN}✅ Data Freshness: Recent (${time_diff}s ago)${NC}"
        else
            echo -e "${YELLOW}⚠️  Data Freshness: Old (${time_diff}s ago)${NC}"
        fi
    else
        echo -e "${RED}❌ Data Freshness: No timestamp${NC}"
    fi
else
    echo -e "${RED}❌ Data Freshness: No items found${NC}"
fi

echo ""
echo -e "${BLUE}💡 Next Steps:${NC}"
echo "1. If host is not available, check agent connection:"
echo "   docker logs telemetry-zabbix-agent-GC-aro21-agent"
echo ""
echo "2. If items are not found, check Zabbix Server configuration:"
echo "   - Verify host is configured correctly"
echo "   - Check if items are enabled"
echo ""
echo "3. If data is old, check agent data collection:"
echo "   docker exec telemetry-zabbix-agent-GC-aro21-agent zabbix_agent2 -t 'net.if.in[eth0]'"
echo ""
echo "4. View data in Grafana:"
echo "   http://100.64.0.113:3000"
echo "   Dashboard: System Overview > Network Traffic - All Agents (MBps)"

# Logout
echo ""
zabbix_api_call "user.logout" "[]" "$auth_token" > /dev/null 2>&1

