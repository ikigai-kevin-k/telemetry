#!/bin/bash

# Update existing Zabbix Items for ARO-002-1 Agent Network Traffic
# This script updates existing items to use custom keys and preprocessing

set -euo pipefail

# Configuration
ZABBIX_URL="${ZABBIX_URL:-http://100.64.0.113:8080/api_jsonrpc.php}"
ZABBIX_USER="${ZABBIX_USER:-admin}"
ZABBIX_PASSWORD="${ZABBIX_PASSWORD:-admin}"
HOST_NAME="GC-ARO-002-1-agent"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "🔧 Updating Zabbix Items for ARO-002-1 Network Traffic"
echo "====================================================="
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

if [ "$auth_token" = "null" ] || [ -z "$auth_token" ]; then
    echo -e "${RED}❌ Authentication failed${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Authentication successful${NC}"
echo ""

# Step 2: Get host ID first
echo -e "${BLUE}Step 2: Getting host ID...${NC}"
host_response=$(zabbix_api_call "host.get" "{
    \"output\": [\"hostid\"],
    \"filter\": {
        \"host\": [\"$HOST_NAME\"]
    }
}" "$auth_token")

host_id=$(echo "$host_response" | jq -r '.result[0].hostid' 2>/dev/null)

if [ "$host_id" = "null" ] || [ -z "$host_id" ]; then
    echo -e "${RED}❌ Host not found${NC}"
    exit 1
fi

echo "   Host ID: $host_id"
echo ""

# Step 3: Get existing items
echo -e "${BLUE}Step 3: Finding existing network items...${NC}"
items_response=$(zabbix_api_call "item.get" "{
    \"output\": [\"itemid\", \"name\", \"key_\"],
    \"hostids\": [\"$host_id\"],
    \"search\": {
        \"key_\": \"net.if\"
    },
    \"searchWildcards\": true
}" "$auth_token")

echo "   Found items:"
echo "$items_response" | jq -r '.result[] | "   - \(.name) (\(.key_)) [ID: \(.itemid)]"' 2>/dev/null
echo ""

rx_item_id=$(echo "$items_response" | jq -r '.result[] | select(.key_=="net.if.in[eth0]") | .itemid' 2>/dev/null | head -1)
tx_item_id=$(echo "$items_response" | jq -r '.result[] | select(.key_=="net.if.out[eth0]") | .itemid' 2>/dev/null | head -1)

# Also check for items with similar names
if [ -z "$rx_item_id" ] || [ "$rx_item_id" = "null" ]; then
    rx_item_id=$(echo "$items_response" | jq -r '.result[] | select(.key_ | contains("net.if.in") and contains("eth0")) | .itemid' 2>/dev/null | head -1)
fi

if [ -z "$tx_item_id" ] || [ "$tx_item_id" = "null" ]; then
    tx_item_id=$(echo "$items_response" | jq -r '.result[] | select(.key_ | contains("net.if.out") and contains("eth0")) | .itemid' 2>/dev/null | head -1)
fi

if [ -z "$rx_item_id" ] || [ "$rx_item_id" = "null" ]; then
    echo -e "${YELLOW}⚠️  RX item (net.if.in[eth0]) not found. Will create new item.${NC}"
    rx_item_id=""
fi

if [ -z "$tx_item_id" ] || [ "$tx_item_id" = "null" ]; then
    echo -e "${YELLOW}⚠️  TX item (net.if.out[eth0]) not found. Will create new item.${NC}"
    tx_item_id=""
fi

# Preprocessing steps
preprocessing_steps='[
    {
        "type": "1",
        "params": "",
        "error_handler": "0",
        "error_handler_params": ""
    },
    {
        "type": "6",
        "params": "8",
        "error_handler": "0",
        "error_handler_params": ""
    }
]'

# Step 4: Update or create RX item
if [ -n "$rx_item_id" ] && [ "$rx_item_id" != "null" ]; then
    echo -e "${BLUE}Step 4: Updating RX item (ID: $rx_item_id)...${NC}"
    update_params=$(jq -n \
        --arg itemid "$rx_item_id" \
        --argjson preprocessing "$preprocessing_steps" \
        '{
            itemid: $itemid,
            preprocessing: $preprocessing
        }')
    
    update_response=$(zabbix_api_call "item.update" "$update_params" "$auth_token")
    result=$(echo "$update_response" | jq -r '.result.itemids[0] // empty' 2>/dev/null)
    
    if [ -n "$result" ]; then
        echo -e "${GREEN}✅ RX item updated successfully${NC}"
    else
        error_msg=$(echo "$update_response" | jq -r '.error.message // empty' 2>/dev/null)
        echo -e "${RED}❌ Failed to update RX item${NC}"
        if [ -n "$error_msg" ]; then
            echo -e "${RED}   Error: $error_msg${NC}"
        fi
        echo "   Response: $update_response"
    fi
else
    echo -e "${YELLOW}⚠️  RX item not found. Please create it manually via Zabbix Web UI.${NC}"
fi

# Step 5: Update or create TX item
if [ -n "$tx_item_id" ] && [ "$tx_item_id" != "null" ]; then
    echo -e "${BLUE}Step 4: Updating TX item (ID: $tx_item_id)...${NC}"
    update_params=$(jq -n \
        --arg itemid "$tx_item_id" \
        --argjson preprocessing "$preprocessing_steps" \
        '{
            itemid: $itemid,
            key_: "custom.net.if.out.bytes[eth0]",
            preprocessing: $preprocessing
        }')
    
    update_response=$(zabbix_api_call "item.update" "$update_params" "$auth_token")
    result=$(echo "$update_response" | jq -r '.result.itemids[0] // empty' 2>/dev/null)
    
    if [ -n "$result" ]; then
        echo -e "${GREEN}✅ TX item updated successfully${NC}"
    else
        error_msg=$(echo "$update_response" | jq -r '.error.message // empty' 2>/dev/null)
        echo -e "${RED}❌ Failed to update TX item${NC}"
        if [ -n "$error_msg" ]; then
            echo -e "${RED}   Error: $error_msg${NC}"
        fi
        echo "   Response: $update_response"
    fi
else
    echo -e "${YELLOW}⚠️  TX item not found. Please create it manually via Zabbix Web UI.${NC}"
fi

# Logout
zabbix_api_call "user.logout" "[]" "$auth_token" > /dev/null 2>&1

echo ""
echo -e "${GREEN}✅ Update process completed${NC}"

