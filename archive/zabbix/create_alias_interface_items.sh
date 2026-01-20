#!/usr/bin/env bash
set -euo pipefail

# Purpose: For hosts whose real NIC is eth0, create calculated items that mimic
#          "Interface enp86s0: Bits received (Rate)" so Grafana panels expecting
#          enp86s0 still work.
#
# Usage:
#   ./create_alias_interface_items.sh \
#     --url http://localhost:8080/api_jsonrpc.php \
#     --user admin --password admin \
#     --alias-name enp86s0 --real-name eth0 \
#     --host GC-ARO-002-1-agent \
#     --host GC-ARO-002-2-agent

ZABBIX_URL=""
ZABBIX_USER=""
ZABBIX_PASSWORD=""
ALIAS_IF="enp86s0"
REAL_IF="eth0"
declare -a HOSTS=()

while (( "$#" )); do
  case "$1" in
    --url) ZABBIX_URL="$2"; shift 2 ;;
    --user) ZABBIX_USER="$2"; shift 2 ;;
    --password) ZABBIX_PASSWORD="$2"; shift 2 ;;
    --alias-name) ALIAS_IF="$2"; shift 2 ;;
    --real-name) REAL_IF="$2"; shift 2 ;;
    --host) HOSTS+=("$2"); shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$ZABBIX_URL" || -z "$ZABBIX_USER" || -z "$ZABBIX_PASSWORD" || ${#HOSTS[@]} -eq 0 ]]; then
  echo "Missing arguments. See script header for usage." >&2
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

create_or_update(){
  local host="$1"
  local item_name="Interface $ALIAS_IF: Bits received (Rate)"
  local item_key="alias.net.if.in.rate[$ALIAS_IF]"

  local hostid=$(curl_json "{\
    \"jsonrpc\": \"2.0\",\
    \"method\": \"host.get\",\
    \"params\": {\"output\": [\"hostid\"], \"filter\": {\"host\": [\"$host\"]}},\
    \"auth\": \"$AUTH\",\
    \"id\": 1\
  }" | jq -r .result[0].hostid)

  if [[ -z "$hostid" || "$hostid" == "null" ]]; then
    echo "Host not found: $host" >&2
    return 1
  fi

  # Find master item (eth0 bytes in counter)
  local keystr=\"net.if.in[\\\"$REAL_IF\\\"]\"
  local master=$(curl_json "{\
    \"jsonrpc\": \"2.0\",\
    \"method\": \"item.get\",\
    \"params\": {\"output\": [\"itemid\", \"key_\"], \"hostids\": [\"$hostid\"], \"filter\": {\"key_\": [\"$keystr\"]}},\
    \"auth\": \"$AUTH\",\
    \"id\": 1\
  }")
  local master_id=$(echo "$master" | jq -r .result[0].itemid)
  if [[ -z "$master_id" || "$master_id" == "null" ]]; then
    echo "$host: master item net.if.in[$REAL_IF] not found; ensure template OS Linux is linked and LLD created items." >&2
    return 1
  fi

  # Does alias already exist?
  local existing=$(curl_json "{\
    \"jsonrpc\": \"2.0\",\
    \"method\": \"item.get\",\
    \"params\": {\"output\": [\"itemid\"], \"hostids\": [\"$hostid\"], \"filter\": {\"name\": [\"$item_name\"]}},\
    \"auth\": \"$AUTH\",\
    \"id\": 1\
  }")
  local itemid=$(echo "$existing" | jq -r .result[0].itemid)

  # Common preprocessing: change per second then multiply by 8 to convert to bps
  local preprocessing='[{"type":10,"params":"","error_handler":0,"error_handler_params":""},{"type":1,"params":"8","error_handler":0,"error_handler_params":""}]'

  if [[ -n "$itemid" && "$itemid" != "null" ]]; then
    echo "$host: updating existing alias item ($itemid)"
    payload=$(jq -n \
      --arg itemid "$itemid" \
      --arg name "$item_name" \
      --arg key "$item_key" \
      --arg expr "last(//net.if.in[$REAL_IF])" \
      --argjson pp "$preprocessing" \
      '{jsonrpc:"2.0", method:"item.update", params:{itemid:$itemid, name:$name, key_:$key, preprocessing:$pp}, auth:null, id:1}')
    payload=$(echo "$payload" | jq --arg a "$AUTH" '.auth=$a')
    resp=$(curl -sS -X POST -H "Content-Type: application/json" -d "$payload" "$ZABBIX_URL")
    echo "$resp" | jq -e '.error' >/dev/null 2>&1 && { echo "API error: $resp" >&2; exit 1; } || true
  else
    echo "$host: creating alias item"
    payload=$(jq -n \
      --arg hostid "$hostid" \
      --arg name "$item_name" \
      --arg key "$item_key" \
      --arg master "$master_id" \
      --argjson pp "$preprocessing" \
      '{jsonrpc:"2.0", method:"item.create", params:{hostid:$hostid, name:$name, key_:$key, type:18, master_itemid:$master, value_type:0, units:"bps", preprocessing:$pp}, auth:null, id:1}')
    payload=$(echo "$payload" | jq --arg a "$AUTH" '.auth=$a')
    resp=$(curl -sS -X POST -H "Content-Type: application/json" -d "$payload" "$ZABBIX_URL")
    echo "$resp" | jq -e '.error' >/dev/null 2>&1 && { echo "API error: $resp" >&2; exit 1; } || true
  fi

  echo "$host: alias item ready -> $item_name"
}

for h in "${HOSTS[@]}"; do
  create_or_update "$h"
done

echo "Done. Values will appear after next poll (≤1–2 min)."


