#!/bin/bash

# Zabbix API configuration
ZABBIX_URL="http://localhost:8080/api_jsonrpc.php"
ZABBIX_USER="admin"
ZABBIX_PASSWORD="admin"

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

# Function to search for Linux template
search_linux_template() {
    local auth_token="$1"
    
    echo "Searching for Linux templates..."
    curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "{
            \"jsonrpc\": \"2.0\",
            \"method\": \"template.get\",
            \"params\": {
                \"output\": [\"templateid\", \"host\", \"name\"],
                \"filter\": {
                    \"host\": [\"Linux by Zabbix agent\"]
                }
            },
            \"auth\": \"$auth_token\",
            \"id\": 1
        }" \
        "$ZABBIX_URL" | jq '.result[]'
}

# Function to create a simple Linux template
create_simple_linux_template() {
    local auth_token="$1"
    
    echo "Creating simple Linux template..."
    
    # First create the template
    local template_result=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "{
            \"jsonrpc\": \"2.0\",
            \"method\": \"template.create\",
            \"params\": {
                \"host\": \"Linux by Zabbix agent Simple\",
                \"name\": \"Linux by Zabbix agent Simple\",
                \"groups\": [{\"groupid\": \"1\"}],
                \"description\": \"Simple Linux template for Zabbix agent monitoring\"
            },
            \"auth\": \"$auth_token\",
            \"id\": 1
        }" \
        "$ZABBIX_URL")
    
    echo "Template creation result: $template_result"
    
    local template_id=$(echo "$template_result" | jq -r '.result.templateids[0]')
    
    if [ "$template_id" != "null" ] && [ -n "$template_id" ]; then
        echo "Template created with ID: $template_id"
        
        # Add basic items
        echo "Adding basic items..."
        curl -s -X POST \
            -H "Content-Type: application/json" \
            -d "{
                \"jsonrpc\": \"2.0\",
                \"method\": \"item.create\",
                \"params\": {
                    \"hostid\": \"$template_id\",
                    \"items\": [
                        {
                            \"name\": \"Agent ping\",
                            \"key\": \"agent.ping\",
                            \"type\": 7,
                            \"value_type\": 3,
                            \"delay\": \"1m\",
                            \"description\": \"Agent ping check\"
                        },
                        {
                            \"name\": \"Agent version\",
                            \"key\": \"agent.version\",
                            \"type\": 7,
                            \"value_type\": 1,
                            \"delay\": \"1h\",
                            \"description\": \"Agent version\"
                        },
                        {
                            \"name\": \"System uptime\",
                            \"key\": \"system.uptime\",
                            \"type\": 7,
                            \"value_type\": 3,
                            \"delay\": \"1m\",
                            \"description\": \"System uptime in seconds\"
                        }
                    ]
                },
                \"auth\": \"$auth_token\",
                \"id\": 1
            }" \
            "$ZABBIX_URL" | jq '.result'
    else
        echo "Failed to create template"
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

echo "Searching for existing Linux template..."
search_linux_template "$AUTH_TOKEN"

echo "Creating simple Linux template..."
create_simple_linux_template "$AUTH_TOKEN"

echo "Script completed"
