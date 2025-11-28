#!/usr/bin/env bash
set -euo pipefail

# Purpose: Create "Interface eth0: Bits received" items for ARO-002-1 and ARO-002-2 agents
#          This script creates the items directly using Zabbix API
#
# Usage:
#   ./create_eth0_interface_items.sh \
#     --url http://localhost:8080/api_jsonrpc.php \
#     --user Admin --password zabbix \
#     --host GC-ARO-002-1-agent \
#     --host GC-ARO-002-2-agent

ZABBIX_URL=""
ZABBIX_USER=""
ZABBIX_PASSWORD=""
declare -a HOSTS=()

while (( "$#" )); do
  case "$1" in
    --url) ZABBIX_URL="$2"; shift 2 ;;
    --user) ZABBIX_USER="$2"; shift 2 ;;
    --password) ZABBIX_PASSWORD="$2"; shift 2 ;;
    --host) HOSTS+=("$2"); shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$ZABBIX_URL" || -z "$ZABBIX_USER" || -z "$ZABBIX_PASSWORD" || ${#HOSTS[@]} -eq 0 ]]; then
  echo "Missing arguments." >&2
  echo "Usage: $0 --url <zabbix_url> --user <user> --password <password> --host <host1> [--host <host2> ...]" >&2
  exit 2
fi

curl_json(){
  local json="$1"
  curl -sS -X POST -H "Content-Type: application/json" -d "$json" "$ZABBIX_URL"
}

AUTH=$(curl_json "{\
  \"jsonrpc\": \"2.0\",\
  \"method\": \"user.login\",\
  \"params\": {\"user\": \"$ZABBIX_USER\", \"password\": \"$ZABBIX_PASSWORD\"},\
  \"id\": 1\
}" | jq -r .result)

if [[ -z "$AUTH" || "$AUTH" == "null" ]]; then
  echo "Auth failed" >&2
  exit 1
fi

echo "Authenticated to Zabbix API"

create_item(){
  local host="$1"
  local item_name="Interface eth0: Bits received"
  local item_key="net.if.in[eth0]"

  # Get host ID
  local hostid=$(curl_json "{\
    \"jsonrpc\": \"2.0\",\
    \"method\": \"host.get\",\
    \"params\": {\"output\": [\"hostid\"], \"filter\": {\"host\": [\"$host\"]}},\
    \"auth\": \"$AUTH\",\
    \"id\": 1\
  }" | jq -r .result[0].hostid)

  if [[ -z "$hostid" || "$hostid" == "null" ]]; then
    echo "❌ Host not found: $host" >&2
    return 1
  fi

  echo "Found host: $host (hostid: $hostid)"

  # Check if item already exists
  local existing=$(curl_json "{\
    \"jsonrpc\": \"2.0\",\
    \"method\": \"item.get\",\
    \"params\": {\"output\": [\"itemid\", \"name\", \"status\"], \"hostids\": [\"$hostid\"], \"filter\": {\"name\": [\"$item_name\"]}},\
    \"auth\": \"$AUTH\",\
    \"id\": 1\
  }")

  local itemid=$(echo "$existing" | jq -r .result[0].itemid)
  local item_status=$(echo "$existing" | jq -r .result[0].status // "null")

  if [[ -n "$itemid" && "$itemid" != "null" ]]; then
    if [[ "$item_status" == "0" ]]; then
      echo "✅ Item already exists and is enabled: $item_name (itemid: $itemid)"
      return 0
    else
      echo "⚠️  Item exists but is disabled. Enabling..."
      # Enable the item
      local result=$(curl_json "{\
        \"jsonrpc\": \"2.0\",\
        \"method\": \"item.update\",\
        \"params\": {\"itemid\": \"$itemid\", \"status\": 0},\
        \"auth\": \"$AUTH\",\
        \"id\": 1\
      }")
      if echo "$result" | jq -e '.error' > /dev/null 2>&1; then
        echo "❌ Failed to enable item: $(echo "$result" | jq -r .error.message)" >&2
        return 1
      else
        echo "✅ Item enabled successfully"
        return 0
      fi
    fi
  fi

  # Get interface ID for the host
  local interface_result=$(curl_json "{\
    \"jsonrpc\": \"2.0\",\
    \"method\": \"hostinterface.get\",\
    \"params\": {\"output\": [\"interfaceid\"], \"hostids\": [\"$hostid\"]},\
    \"auth\": \"$AUTH\",\
    \"id\": 1\
  }")
  local interfaceid=$(echo "$interface_result" | jq -r '.result[0].interfaceid // "0"')

  # Create the item
  echo "Creating item: $item_name for host: $host"
  local preprocessing_json='[{"type":10,"params":"","error_handler":0,"error_handler_params":""},{"type":1,"params":"8","error_handler":0,"error_handler_params":""}]'
  local result=$(curl_json "{\
    \"jsonrpc\": \"2.0\",\
    \"method\": \"item.create\",\
    \"params\": {\
      \"name\": \"$item_name\",\
      \"key_\": \"$item_key\",\
      \"hostid\": \"$hostid\",\
      \"type\": 0,\
      \"value_type\": 3,\
      \"interfaceid\": \"$interfaceid\",\
      \"units\": \"B\",\
      \"delay\": \"30s\",\
      \"status\": 0,\
      \"preprocessing\": $preprocessing_json\
    },\
    \"auth\": \"$AUTH\",\
    \"id\": 1\
  }")

  if echo "$result" | jq -e '.error' > /dev/null 2>&1; then
    echo "❌ Failed to create item: $(echo "$result" | jq -r .error.message)" >&2
    return 1
  else
    local new_itemid=$(echo "$result" | jq -r .result.itemids[0])
    echo "✅ Item created successfully (itemid: $new_itemid)"
    return 0
  fi
}

# Process each host
for host in "${HOSTS[@]}"; do
  echo ""
  echo "Processing host: $host"
  create_item "$host"
done

echo ""
echo "Done!"

