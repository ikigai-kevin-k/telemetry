#!/usr/bin/env bash
set -euo pipefail

# Purpose: Provision one or more Zabbix hosts with the same groups/templates as a source host (e.g., ARO11)
# Usage:
#   ./provision_hosts_like_ARO11.sh \
#     --url http://localhost:8080/api_jsonrpc.php \
#     --user Admin --password zabbix \
#     --source "GC-ARO-001-1-agent" \
#     --targets "GC-ARO-002-2-agent=10.0.0.22,enp86s0" "GC-ARO-003-3-agent=10.0.0.23,enp86s0"
#
# Each --targets entry format: <zabbixHostName>=<agentIP>,<primaryInterfaceName>
# - <primaryInterfaceName> is optional; when omitted, defaults to "eth0" (only for description note)

ZABBIX_URL=""
ZABBIX_USER=""
ZABBIX_PASSWORD=""
SOURCE_HOST_NAME=""
declare -a TARGET_SPECS=()

while (( "$#" )); do
  case "$1" in
    --url) ZABBIX_URL="$2"; shift 2 ;;
    --user) ZABBIX_USER="$2"; shift 2 ;;
    --password) ZABBIX_PASSWORD="$2"; shift 2 ;;
    --source) SOURCE_HOST_NAME="$2"; shift 2 ;;
    --targets) TARGET_SPECS+=("$2"); shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "${ZABBIX_URL}" || -z "${ZABBIX_USER}" || -z "${ZABBIX_PASSWORD}" || -z "${SOURCE_HOST_NAME}" || ${#TARGET_SPECS[@]} -eq 0 ]]; then
  echo "Missing required arguments." >&2
  echo "Example: $0 --url http://localhost:8080/api_jsonrpc.php --user Admin --password zabbix --source GC-ARO-001-1-agent --targets 'GC-ARO-002-2-agent=10.0.0.22,enp86s0'" >&2
  exit 2
fi

curl_json() {
  local json="$1"
  curl -sS -X POST -H "Content-Type: application/json" -d "$json" "$ZABBIX_URL"
}

auth_token=$(curl_json "{\
  \"jsonrpc\": \"2.0\",\
  \"method\": \"user.login\",\
  \"params\": {\"user\": \"$ZABBIX_USER\", \"password\": \"$ZABBIX_PASSWORD\"},\
  \"id\": 1\
}" | jq -r '.result')

if [[ -z "$auth_token" || "$auth_token" == "null" ]]; then
  echo "Failed to authenticate to Zabbix API" >&2
  exit 1
fi

echo "Authenticated to Zabbix API"

# Get source host info (groups/templates) by name
source_host=$(curl_json "{\
  \"jsonrpc\": \"2.0\",\
  \"method\": \"host.get\",\
  \"params\": {\
    \"output\": [\"hostid\", \"host\"],\
    \"selectGroups\": [\"groupid\"],\
    \"selectParentTemplates\": [\"templateid\"],\
    \"filter\": {\"host\": [\"$SOURCE_HOST_NAME\"]}\
  },\
  \"auth\": \"$auth_token\",\
  \"id\": 1\
}")

source_hostid=$(echo "$source_host" | jq -r '.result[0].hostid')
if [[ -z "$source_hostid" || "$source_hostid" == "null" ]]; then
  echo "Source host '$SOURCE_HOST_NAME' not found." >&2
  exit 1
fi

source_groups=$(echo "$source_host" | jq -c '.result[0].groups | map({groupid: .groupid})')
source_templates=$(echo "$source_host" | jq -c '.result[0].parentTemplates | map({templateid: .templateid})')

echo "Source hostid: $source_hostid"
echo "Groups: $source_groups"
echo "Templates: $source_templates"

create_or_get_host() {
  local host_name="$1"; shift
  local agent_ip="$1"; shift
  local interface_name_note="$1"; shift

  # Check if host already exists
  local existing=$(curl_json "{\
    \"jsonrpc\": \"2.0\",\
    \"method\": \"host.get\",\
    \"params\": {\"output\": [\"hostid\"], \"filter\": {\"host\": [\"$host_name\"]}},\
    \"auth\": \"$auth_token\",\
    \"id\": 1\
  }")
  local hostid=$(echo "$existing" | jq -r '.result[0].hostid // empty')
  if [[ -n "$hostid" ]]; then
    echo "$host_name already exists (hostid=$hostid). Updating interface and templates..."
    # Update templates
    curl_json "{\
      \"jsonrpc\": \"2.0\",\
      \"method\": \"host.update\",\
      \"params\": {\
        \"hostid\": \"$hostid\",\
        \"templates\": $source_templates\
      },\
      \"auth\": \"$auth_token\",\
      \"id\": 1\
    }" >/dev/null

    # Update or create agent interface (type=1, main=1, useip=1)
    interfaces=$(curl_json "{\
      \"jsonrpc\": \"2.0\",\
      \"method\": \"hostinterface.get\",\
      \"params\": {\"output\": \"extend\", \"hostids\": [\"$hostid\"]},\
      \"auth\": \"$auth_token\",\
      \"id\": 1\
    }")
    interface_id=$(echo "$interfaces" | jq -r '.result[] | select(.type=="1") | .interfaceid' | head -n1)
    if [[ -n "$interface_id" ]]; then
      curl_json "{\
        \"jsonrpc\": \"2.0\",\
        \"method\": \"hostinterface.update\",\
        \"params\": {\
          \"interfaceid\": \"$interface_id\",\
          \"ip\": \"$agent_ip\"\
        },\
        \"auth\": \"$auth_token\",\
        \"id\": 1\
      }" >/dev/null
    else
      curl_json "{\
        \"jsonrpc\": \"2.0\",\
        \"method\": \"hostinterface.create\",\
        \"params\": [{\
          \"hostid\": \"$hostid\",\
          \"type\": 1, \"main\": 1, \"useip\": 1, \"ip\": \"$agent_ip\", \"dns\": \"\", \"port\": \"10050\"\
        }],\
        \"auth\": \"$auth_token\",\
        \"id\": 1\
      }" >/dev/null
    fi
    echo "$host_name updated."
    return 0
  fi

  echo "Creating host $host_name ($agent_ip) ..."
  payload=$(jq -n \
    --arg host "$host_name" \
    --arg ip "$agent_ip" \
    --arg note "primary interface: ${interface_name_note}" \
    --argjson groups "$source_groups" \
    --argjson templates "$source_templates" \
    '{jsonrpc:"2.0", method:"host.create", params:{host:$host, description:$note, groups:$groups, templates:$templates, interfaces:[{type:1, main:1, useip:1, ip:$ip, dns:"", port:"10050"}]}, auth:null, id:1}')

  # Inject auth after building payload for clarity
  payload=$(echo "$payload" | jq --arg auth "$auth_token" '.auth = $auth')
  result=$(curl -sS -X POST -H "Content-Type: application/json" -d "$payload" "$ZABBIX_URL")
  echo "$result" | jq -e '.result.hostids[0]' >/dev/null || {
    echo "Failed to create $host_name: $(echo "$result" | jq -c '.error // empty')" >&2
    return 1
  }
  echo "$host_name created."
}

for spec in "${TARGET_SPECS[@]}"; do
  # spec format: HostName=IP,iface
  host_name="${spec%%=*}"
  right="${spec#*=}"
  agent_ip="${right%%,*}"
  iface_note="${right#*,}"
  if [[ "$right" == "$agent_ip" ]]; then iface_note="eth0"; fi
  create_or_get_host "$host_name" "$agent_ip" "$iface_note"
done

echo "Done. New hosts should begin collecting data in 1-3 minutes."


