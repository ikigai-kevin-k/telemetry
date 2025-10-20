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

# Function to add template to host
add_template_to_host() {
    local auth_token="$1"
    local host_id="$2"
    local template_id="$3"
    
    echo "Adding template $template_id to host $host_id..."
    
    curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "{
            \"jsonrpc\": \"2.0\",
            \"method\": \"host.update\",
            \"params\": {
                \"hostid\": \"$host_id\",
                \"templates\": [{\"templateid\": \"$template_id\"}]
            },
            \"auth\": \"$auth_token\",
            \"id\": 1
        }" \
        "$ZABBIX_URL" | jq '.result'
}

# Function to get template ID
get_template_id() {
    local auth_token="$1"
    local template_name="$2"
    
    curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "{
            \"jsonrpc\": \"2.0\",
            \"method\": \"template.get\",
            \"params\": {
                \"output\": [\"templateid\"],
                \"filter\": {\"host\": \"$template_name\"}
            },
            \"auth\": \"$auth_token\",
            \"id\": 1
        }" \
        "$ZABBIX_URL" | jq -r '.result[0].templateid'
}

# Main execution
echo "Getting authentication token..."
AUTH_TOKEN=$(get_auth_token)

if [ "$AUTH_TOKEN" = "null" ] || [ -z "$AUTH_TOKEN" ]; then
    echo "Failed to get authentication token"
    exit 1
fi

echo "Authentication successful"

echo "Getting template ID for 'Linux by Zabbix agent'..."
TEMPLATE_ID=$(get_template_id "$AUTH_TOKEN" "Linux by Zabbix agent")

if [ "$TEMPLATE_ID" = "null" ] || [ -z "$TEMPLATE_ID" ]; then
    echo "Template 'Linux by Zabbix agent' not found"
    exit 1
fi

echo "Template ID: $TEMPLATE_ID"

echo "Adding template to host GC-aro12-agent..."
add_template_to_host "$AUTH_TOKEN" "10643" "$TEMPLATE_ID"

echo "Template added successfully!"
echo "Please wait 2-3 minutes for the host to start collecting data."
