#!/usr/bin/env bash
set -euo pipefail

# Purpose: Sync ALL agent hosts (excluding GC-ARO-001-1-agent) so they inherit
#          the same groups and templates as the source host (ARO11).
# Notes:
# - This does NOT change existing agent interface IPs. It only sets templates/groups.
# - After templates are applied, LLD will create interface items (e.g., enp86s0) automatically within a few minutes.

ZABBIX_URL=${ZABBIX_URL:-"http://localhost:8080/api_jsonrpc.php"}
ZABBIX_USER=${ZABBIX_USER:-"Admin"}
ZABBIX_PASSWORD=${ZABBIX_PASSWORD:-"zabbix"}
SOURCE_HOST_NAME=${SOURCE_HOST_NAME:-"GC-ARO-001-1-agent"}

curl_json() {
  local json="$1"
  curl -sS -X POST -H "Content-Type: application/json" -d "$json" "$ZABBIX_URL"
}

echo "Authenticating to Zabbix API ..."
AUTH=$(curl_json "{\
  \"jsonrpc\": \"2.0\",\
  \"method\": \"user.login\",\
  \"params\": {\"user\": \"$ZABBIX_USER\", \"password\": \"$ZABBIX_PASSWORD\"},\
  \"id\": 1\
}" | jq -r '.result')

if [[ -z "$AUTH" || "$AUTH" == "null" ]]; then
  echo "ERROR: authentication failed" >&2
  exit 1
fi

echo "Fetching source host groups/templates from $SOURCE_HOST_NAME ..."
SRC=$(curl_json "{\
  \"jsonrpc\": \"2.0\",\
  \"method\": \"host.get\",\
  \"params\": {\
    \"output\": [\"hostid\"],\
    \"selectGroups\": [\"groupid\"],\
    \"selectParentTemplates\": [\"templateid\"],\
    \"filter\": {\"host\": [\"$SOURCE_HOST_NAME\"]}\
  },\
  \"auth\": \"$AUTH\",\
  \"id\": 1\
}")

SRC_HOSTID=$(echo "$SRC" | jq -r '.result[0].hostid // empty')
SRC_GROUPS=$(echo "$SRC" | jq -c '.result[0].groups | map({groupid:.groupid})')
SRC_TEMPLATES=$(echo "$SRC" | jq -c '.result[0].parentTemplates | map({templateid:.templateid})')

if [[ -z "$SRC_HOSTID" ]]; then
  echo "ERROR: source host not found: $SOURCE_HOST_NAME" >&2
  exit 1
fi

echo "Listing all agent hosts excluding $SOURCE_HOST_NAME ..."
HOSTS=$(curl_json "{\
  \"jsonrpc\": \"2.0\",\
  \"method\": \"host.get\",\
  \"params\": {\
    \"output\": [\"hostid\", \"host\"],\
    \"search\": {\"host\": \"GC-ARO-\"},\
    \"sortfield\": \"host\"\
  },\
  \"auth\": \"$AUTH\",\
  \"id\": 1\
}")

num=0
echo "$HOSTS" | jq -c '.result[]' | while read -r H; do
  name=$(echo "$H" | jq -r '.host')
  hostid=$(echo "$H" | jq -r '.hostid')
  if [[ "$name" == "$SOURCE_HOST_NAME" ]]; then
    continue
  fi
  echo "Updating $name (hostid=$hostid) with source templates/groups ..."
  payload=$(jq -n \
    --arg hostid "$hostid" \
    --argjson groups "$SRC_GROUPS" \
    --argjson templates "$SRC_TEMPLATES" \
    '{jsonrpc:"2.0", method:"host.update", params:{hostid:$hostid, groups:$groups, templates:$templates}, auth:null, id:1}')
  payload=$(echo "$payload" | jq --arg a "$AUTH" '.auth=$a')
  curl -sS -X POST -H "Content-Type: application/json" -d "$payload" "$ZABBIX_URL" | jq -e '.result.hostids[0]' >/dev/null
  echo "  -> $name synced"
  num=$((num+1))
done

echo "Sync process dispatched. New/updated items (e.g., enp86s0) will populate within a few minutes."


