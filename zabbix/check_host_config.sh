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

# Function to check host configuration
check_host_config() {
    local auth_token="$1"
    
    echo "Checking host configuration for GC-aro12-agent..."
    
    # Get host information
    local host_info=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "{
            \"jsonrpc\": \"2.0\",
            \"method\": \"host.get\",
            \"params\": {
                \"output\": [\"hostid\", \"host\", \"name\", \"status\"],
                \"filter\": {\"host\": \"GC-aro12-agent\"}
            },
            \"auth\": \"$auth_token\",
            \"id\": 1
        }" \
        "$ZABBIX_URL")
    
    echo "Host info: $host_info"
    
    local host_id=$(echo "$host_info" | jq -r '.result[0].hostid')
    
    if [ "$host_id" != "null" ] && [ -n "$host_id" ]; then
        echo "Host ID: $host_id"
        
        # Get host interfaces
        echo "Getting host interfaces..."
        curl -s -X POST \
            -H "Content-Type: application/json" \
            -d "{
                \"jsonrpc\": \"2.0\",
                \"method\": \"hostinterface.get\",
                \"params\": {
                    \"output\": [\"interfaceid\", \"hostid\", \"type\", \"ip\", \"port\", \"main\"],
                    \"hostids\": [\"$host_id\"]
                },
                \"auth\": \"$auth_token\",
                \"id\": 1
            }" \
            "$ZABBIX_URL" | jq '.result'
    else
        echo "Host not found"
    fi
}

# Main execution
echo "Getting authentication token..."
AUTH_TOKEN=$(get_auth_token)

if [ "$AUTH_TOKEN" = "null" ] || [ -z "$AUTH_TOKEN" ]; then
    echo "Failed to get authentication token"
    exit 1
fi

echo "Authentication successful"
check_host_config "$AUTH_TOKEN"
