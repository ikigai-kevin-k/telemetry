#!/bin/bash

# Zabbix API configuration
ZABBIX_URL="http://localhost:8080/api_jsonrpc.php"
ZABBIX_USER="Admin"
ZABBIX_PASSWORD="zabbix"

# Function to get authentication token
get_auth_token() {
    curl -s -X POST \
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
        "$ZABBIX_URL" | jq -r '.result'
}

# Function to update host interface for active checks
update_host_interface() {
    local auth_token="$1"
    local interface_id="$2"
    
    echo "Updating host interface for active checks..."
    
    curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "{
            \"jsonrpc\": \"2.0\",
            \"method\": \"hostinterface.update\",
            \"params\": {
                \"interfaceid\": \"$interface_id\",
                \"type\": \"1\",
                \"ip\": \"100.64.0.149\",
                \"port\": \"10050\",
                \"main\": \"1\",
                \"useip\": \"1\"
            },
            \"auth\": \"$auth_token\",
            \"id\": 1
        }" \
        "$ZABBIX_URL" | jq '.result'
}

# Function to get interface ID
get_interface_id() {
    local auth_token="$1"
    local host_id="$2"
    
    curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "{
            \"jsonrpc\": \"2.0\",
            \"method\": \"hostinterface.get\",
            \"params\": {
                \"output\": [\"interfaceid\"],
                \"hostids\": [\"$host_id\"]
            },
            \"auth\": \"$auth_token\",
            \"id\": 1
        }" \
        "$ZABBIX_URL" | jq -r '.result[0].interfaceid'
}

# Main execution
echo "Getting authentication token..."
AUTH_TOKEN=$(get_auth_token)

if [ "$AUTH_TOKEN" = "null" ] || [ -z "$AUTH_TOKEN" ]; then
    echo "Failed to get authentication token"
    exit 1
fi

echo "Authentication successful"

echo "Getting interface ID for host GC-aro12-agent..."
INTERFACE_ID=$(get_interface_id "$AUTH_TOKEN" "10643")

if [ "$INTERFACE_ID" = "null" ] || [ -z "$INTERFACE_ID" ]; then
    echo "Interface not found"
    exit 1
fi

echo "Interface ID: $INTERFACE_ID"

echo "Updating interface configuration..."
update_host_interface "$AUTH_TOKEN" "$INTERFACE_ID"

echo "Interface updated successfully!"
echo "Please wait 2-3 minutes for the connection to establish."

