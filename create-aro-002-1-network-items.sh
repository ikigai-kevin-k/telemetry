#!/bin/bash

# Create/Update Zabbix Items for ARO-002-1 Agent Network Traffic
# This script creates or updates items with custom keys and preprocessing

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

echo "🔧 Creating/Updating Zabbix Items for ARO-002-1 Network Traffic"
echo "=============================================================="
echo ""
echo "Configuration:"
echo "  Zabbix URL: $ZABBIX_URL"
echo "  Host Name: $HOST_NAME"
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
echo ""

# Step 2: Get host ID
echo -e "${BLUE}Step 2: Getting host ID for $HOST_NAME...${NC}"
host_response=$(zabbix_api_call "host.get" "{
    \"output\": [\"hostid\", \"host\", \"name\"],
    \"filter\": {
        \"host\": [\"$HOST_NAME\"]
    }
}" "$auth_token")

host_id=$(echo "$host_response" | jq -r '.result[0].hostid' 2>/dev/null)
host_count=$(echo "$host_response" | jq '.result | length' 2>/dev/null)

if [ "$host_count" -eq 0 ] || [ "$host_id" = "null" ] || [ -z "$host_id" ]; then
    echo -e "${RED}❌ Host '$HOST_NAME' not found${NC}"
    echo "   Response: $host_response"
    exit 1
fi

echo -e "${GREEN}✅ Host found${NC}"
echo "   Host ID: $host_id"
echo ""

# Step 3: Check existing items
echo -e "${BLUE}Step 3: Checking existing network items...${NC}"

# Check for old items
old_items_response=$(zabbix_api_call "item.get" "{
    \"output\": [\"itemid\", \"name\", \"key_\", \"status\"],
    \"hostids\": [\"$host_id\"],
    \"filter\": {
        \"key_\": [\"net.if.in[eth0]\", \"net.if.out[eth0]\"]
    }
}" "$auth_token")

old_items_count=$(echo "$old_items_response" | jq '.result | length' 2>/dev/null)

if [ "$old_items_count" -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Found $old_items_count existing item(s) with old keys:${NC}"
    echo "$old_items_response" | jq -r '.result[] | "   - \(.name) (\(.key_)) [ID: \(.itemid)]"' 2>/dev/null
    echo ""
    echo -e "${YELLOW}   Note: These items will be kept. New items will be created with custom keys.${NC}"
    echo ""
fi

# Check for new items
new_items_response=$(zabbix_api_call "item.get" "{
    \"output\": [\"itemid\", \"name\", \"key_\", \"status\"],
    \"hostids\": [\"$host_id\"],
    \"filter\": {
        \"key_\": [\"custom.net.if.in.bytes[eth0]\", \"custom.net.if.out.bytes[eth0]\"]
    }
}" "$auth_token")

new_items_count=$(echo "$new_items_response" | jq '.result | length' 2>/dev/null)

if [ "$new_items_count" -gt 0 ]; then
    echo -e "${GREEN}✅ Found $new_items_count existing item(s) with new keys:${NC}"
    echo "$new_items_response" | jq -r '.result[] | "   - \(.name) (\(.key_)) [ID: \(.itemid)]"' 2>/dev/null
    echo ""
    echo -e "${YELLOW}   These items already exist. Will update them if needed.${NC}"
    echo ""
    
    # Get item IDs for update
    rx_item_id=$(echo "$new_items_response" | jq -r '.result[] | select(.key_=="custom.net.if.in.bytes[eth0]") | .itemid' 2>/dev/null | head -1)
    tx_item_id=$(echo "$new_items_response" | jq -r '.result[] | select(.key_=="custom.net.if.out.bytes[eth0]") | .itemid' 2>/dev/null | head -1)
else
    echo -e "${YELLOW}⚠️  No items found with new keys. Will create new items.${NC}"
    echo ""
    rx_item_id=""
    tx_item_id=""
fi

# Step 4: Create or update items
echo -e "${BLUE}Step 4: Creating/Updating network traffic items...${NC}"

# Preprocessing steps:
# 1. Change per second (type 1)
# 2. Multiply by 8 (type 6, params: 8)
# Note: Based on existing item structure, types are strings and include error_handler
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

# Item configuration for RX (receive) - build JSON using jq
# Note: Using "key" instead of "key_" as per API documentation
rx_item_config=$(jq -n \
    --arg hostid "$host_id" \
    --argjson preprocessing "$preprocessing_steps" \
    '{
        "name": "Interface eth0: Bits received",
        "key_": "custom.net.if.in.bytes[eth0]",
        "hostid": $hostid,
        "type": 0,
        "value_type": 3,
        "delay": "30s",
        "history": "7d",
        "trends": "365d",
        "status": 0,
        "units": "bps",
        "description": "Network interface eth0 bits received per second (mapped from enp86s0 physical interface)",
        "preprocessing": $preprocessing
    }')

# Item configuration for TX (transmit) - build JSON using jq
tx_item_config=$(jq -n \
    --arg hostid "$host_id" \
    --argjson preprocessing "$preprocessing_steps" \
    '{
        "name": "Interface eth0: Bits sent",
        "key_": "custom.net.if.out.bytes[eth0]",
        "hostid": $hostid,
        "type": 0,
        "value_type": 3,
        "delay": "30s",
        "history": "7d",
        "trends": "365d",
        "status": 0,
        "units": "bps",
        "description": "Network interface eth0 bits sent per second (mapped from enp86s0 physical interface)",
        "preprocessing": $preprocessing
    }')

# Create or update RX item
if [ -n "$rx_item_id" ] && [ "$rx_item_id" != "null" ]; then
    echo -e "${BLUE}Updating RX item (ID: $rx_item_id)...${NC}"
    rx_update_config=$(echo "$rx_item_config" | jq ". + {itemid: \"$rx_item_id\"}")
    update_response=$(zabbix_api_call "item.update" "$rx_update_config" "$auth_token")
    update_result=$(echo "$update_response" | jq -r '.result.itemids[0] // empty' 2>/dev/null)
    
    if [ -n "$update_result" ]; then
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
    echo -e "${BLUE}Creating RX item...${NC}"
    # item.create expects items array in params with hostid at top level
    create_params=$(echo "$rx_item_config" | jq -c --arg hostid "$host_id" '{hostid: $hostid, items: [.]}')
    create_response=$(zabbix_api_call "item.create" "$create_params" "$auth_token")
    rx_item_id=$(echo "$create_response" | jq -r '.result.itemids[0] // empty' 2>/dev/null)
    
    if [ -n "$rx_item_id" ] && [ "$rx_item_id" != "null" ]; then
        echo -e "${GREEN}✅ RX item created successfully (ID: $rx_item_id)${NC}"
    else
        error_msg=$(echo "$create_response" | jq -r '.error.message // empty' 2>/dev/null)
        echo -e "${RED}❌ Failed to create RX item${NC}"
        if [ -n "$error_msg" ]; then
            echo -e "${RED}   Error: $error_msg${NC}"
        fi
        echo "   Response: $create_response"
    fi
fi

# Create or update TX item
if [ -n "$tx_item_id" ] && [ "$tx_item_id" != "null" ]; then
    echo -e "${BLUE}Updating TX item (ID: $tx_item_id)...${NC}"
    tx_update_config=$(echo "$tx_item_config" | jq ". + {itemid: \"$tx_item_id\"}")
    update_response=$(zabbix_api_call "item.update" "$tx_update_config" "$auth_token")
    update_result=$(echo "$update_response" | jq -r '.result.itemids[0] // empty' 2>/dev/null)
    
    if [ -n "$update_result" ]; then
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
    echo -e "${BLUE}Creating TX item...${NC}"
    # item.create expects items array in params with hostid at top level
    create_params=$(echo "$tx_item_config" | jq -c --arg hostid "$host_id" '{hostid: $hostid, items: [.]}')
    create_response=$(zabbix_api_call "item.create" "$create_params" "$auth_token")
    tx_item_id=$(echo "$create_response" | jq -r '.result.itemids[0] // empty' 2>/dev/null)
    
    if [ -n "$tx_item_id" ] && [ "$tx_item_id" != "null" ]; then
        echo -e "${GREEN}✅ TX item created successfully (ID: $tx_item_id)${NC}"
    else
        error_msg=$(echo "$create_response" | jq -r '.error.message // empty' 2>/dev/null)
        echo -e "${RED}❌ Failed to create TX item${NC}"
        if [ -n "$error_msg" ]; then
            echo -e "${RED}   Error: $error_msg${NC}"
        fi
        echo "   Response: $create_response"
    fi
fi

echo ""

# Step 5: Verify items
echo -e "${BLUE}Step 5: Verifying created/updated items...${NC}"
verify_response=$(zabbix_api_call "item.get" "{
    \"output\": [\"itemid\", \"name\", \"key_\", \"status\", \"units\", \"delay\"],
    \"hostids\": [\"$host_id\"],
    \"filter\": {
        \"key_\": [\"custom.net.if.in.bytes[eth0]\", \"custom.net.if.out.bytes[eth0]\"]
    }
}" "$auth_token")

verify_count=$(echo "$verify_response" | jq '.result | length' 2>/dev/null)

if [ "$verify_count" -gt 0 ]; then
    echo -e "${GREEN}✅ Verified $verify_count item(s):${NC}"
    echo "$verify_response" | jq -r '.result[] | "   - \(.name) (\(.key_)) [Status: \(.status), Units: \(.units), Delay: \(.delay)]"' 2>/dev/null
else
    echo -e "${RED}❌ Items not found after creation${NC}"
fi

echo ""

# Step 6: Check preprocessing
echo -e "${BLUE}Step 6: Verifying preprocessing configuration...${NC}"
if [ -n "$rx_item_id" ] && [ "$rx_item_id" != "null" ]; then
    prep_response=$(zabbix_api_call "item.get" "{
        \"output\": [\"itemid\", \"name\", \"key_\"],
        \"itemids\": [\"$rx_item_id\"],
        \"selectPreprocessing\": \"extend\"
    }" "$auth_token")
    
    prep_count=$(echo "$prep_response" | jq '.result[0].preprocessing | length' 2>/dev/null)
    if [ "$prep_count" -gt 0 ]; then
        echo -e "${GREEN}✅ Preprocessing configured ($prep_count steps):${NC}"
        echo "$prep_response" | jq -r '.result[0].preprocessing[] | "   - Type \(.type): \(.params)"' 2>/dev/null
    else
        echo -e "${YELLOW}⚠️  No preprocessing found${NC}"
    fi
fi

echo ""

# Summary
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Summary${NC}"
echo -e "${BLUE}========================================${NC}"

if [ -n "$rx_item_id" ] && [ "$rx_item_id" != "null" ] && [ -n "$tx_item_id" ] && [ "$tx_item_id" != "null" ]; then
    echo -e "${GREEN}✅ Items created/updated successfully${NC}"
    echo "   RX Item ID: $rx_item_id"
    echo "   TX Item ID: $tx_item_id"
    echo ""
    echo -e "${BLUE}💡 Next Steps:${NC}"
    echo "1. Wait 1-2 minutes for Zabbix to start collecting data"
    echo "2. Verify data collection:"
    echo "   zabbix_get -s 100.64.0.143 -k 'custom.net.if.in.bytes[eth0]'"
    echo "3. Check Grafana dashboard:"
    echo "   http://100.64.0.113:3000"
    echo "   Dashboard: System Overview > Network Traffic - All Agents (MBps)"
    echo "4. The dashboard should automatically use the new items if they have the same name"
else
    echo -e "${RED}❌ Some items failed to create/update${NC}"
    echo "   Please check the error messages above"
fi

# Logout
zabbix_api_call "user.logout" "[]" "$auth_token" > /dev/null 2>&1

echo ""

