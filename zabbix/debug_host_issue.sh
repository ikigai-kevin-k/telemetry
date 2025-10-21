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

# Function to check host configuration in detail
check_host_detailed() {
    local auth_token="$1"
    
    echo "=== Detailed Host Configuration Check ==="
    
    # Get host information
    echo "1. Getting host information..."
    local host_info=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "{
            \"jsonrpc\": \"2.0\",
            \"method\": \"host.get\",
            \"params\": {
                \"output\": [\"hostid\", \"host\", \"name\", \"status\", \"available\"],
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
        echo ""
        echo "2. Getting host interfaces..."
        local interfaces=$(curl -s -X POST \
            -H "Content-Type: application/json" \
            -d "{
                \"jsonrpc\": \"2.0\",
                \"method\": \"hostinterface.get\",
                \"params\": {
                    \"output\": [\"interfaceid\", \"hostid\", \"type\", \"ip\", \"port\", \"main\", \"available\"],
                    \"hostids\": [\"$host_id\"]
                },
                \"auth\": \"$auth_token\",
                \"id\": 1
            }" \
            "$ZABBIX_URL")
        
        echo "Interfaces: $interfaces"
        
        # Get host templates
        echo ""
        echo "3. Getting host templates..."
        local templates=$(curl -s -X POST \
            -H "Content-Type: application/json" \
            -d "{
                \"jsonrpc\": \"2.0\",
                \"method\": \"host.get\",
                \"params\": {
                    \"output\": [\"hostid\"],
                    \"hostids\": [\"$host_id\"],
                    \"selectTemplates\": [\"templateid\", \"host\"]
                },
                \"auth\": \"$auth_token\",
                \"id\": 1
            }" \
            "$ZABBIX_URL")
        
        echo "Templates: $templates"
        
        # Check if host is enabled
        echo ""
        echo "4. Checking host status..."
        local status=$(echo "$host_info" | jq -r '.result[0].status')
        local available=$(echo "$host_info" | jq -r '.result[0].available')
        
        echo "Host status: $status (0=enabled, 1=disabled)"
        echo "Host available: $available (0=unknown, 1=available, 2=unavailable)"
        
    else
        echo "ERROR: Host not found in Zabbix database"
    fi
}

# Function to check server configuration
check_server_config() {
    echo ""
    echo "=== Server Configuration Check ==="
    
    echo "1. Checking Zabbix server status..."
    docker ps | grep zabbix-server
    
    echo ""
    echo "2. Checking Zabbix server configuration..."
    docker exec kevin-telemetry-zabbix-server cat /etc/zabbix/zabbix_server.conf | grep -E "(ListenIP|ListenPort|StartPollers|StartTrappers)" | head -10
    
    echo ""
    echo "3. Checking recent server logs..."
    docker logs kevin-telemetry-zabbix-server --tail 20 | grep -E "(GC-aro12-agent|100.64.0.149|active checks|host.*not found)" | tail -10
}

# Main execution
echo "Getting authentication token..."
AUTH_TOKEN=$(get_auth_token)

if [ "$AUTH_TOKEN" = "null" ] || [ -z "$AUTH_TOKEN" ]; then
    echo "Failed to get authentication token"
    exit 1
fi

echo "Authentication successful"
check_host_detailed "$AUTH_TOKEN"
check_server_config

echo ""
echo "=== Recommendations ==="
echo "If the host is found but still not connecting:"
echo "1. Wait 2-3 minutes for the next polling cycle"
echo "2. Check if the host is enabled (status should be 0)"
echo "3. Verify the interface configuration is correct"
echo "4. Check if there are any firewall rules blocking the connection"

