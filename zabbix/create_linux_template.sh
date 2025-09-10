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

# Function to create Linux template
create_linux_template() {
    local auth_token="$1"
    
    echo "Creating Linux by Zabbix agent template..."
    
    curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "{
            \"jsonrpc\": \"2.0\",
            \"method\": \"template.create\",
            \"params\": {
                \"host\": \"Linux by Zabbix agent\",
                \"name\": \"Linux by Zabbix agent\",
                \"groups\": [{\"groupid\": \"1\"}],
                \"description\": \"Template for Linux systems monitored by Zabbix agent\",
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
                    },
                    {
                        \"name\": \"CPU utilization\",
                        \"key\": \"system.cpu.util\",
                        \"type\": 7,
                        \"value_type\": 0,
                        \"delay\": \"1m\",
                        \"description\": \"CPU utilization percentage\"
                    },
                    {
                        \"name\": \"Memory utilization\",
                        \"key\": \"vm.memory.util\",
                        \"type\": 7,
                        \"value_type\": 0,
                        \"delay\": \"1m\",
                        \"description\": \"Memory utilization percentage\"
                    },
                    {
                        \"name\": \"Disk space utilization\",
                        \"key\": \"vfs.fs.util\",
                        \"type\": 7,
                        \"value_type\": 0,
                        \"delay\": \"1m\",
                        \"description\": \"Disk space utilization percentage\"
                    },
                    {
                        \"name\": \"Network interface in\",
                        \"key\": \"net.if.in\",
                        \"type\": 7,
                        \"value_type\": 3,
                        \"delay\": \"1m\",
                        \"description\": \"Network interface incoming traffic\"
                    },
                    {
                        \"name\": \"Network interface out\",
                        \"key\": \"net.if.out\",
                        \"type\": 7,
                        \"value_type\": 3,
                        \"delay\": \"1m\",
                        \"description\": \"Network interface outgoing traffic\"
                    }
                ],
                \"triggers\": [
                    {
                        \"description\": \"Host is unreachable\",
                        \"expression\": \"{Linux by Zabbix agent:agent.ping.nodata(5m)}=1\",
                        \"priority\": 4,
                        \"status\": 0
                    },
                    {
                        \"description\": \"High CPU utilization\",
                        \"expression\": \"{Linux by Zabbix agent:system.cpu.util.avg(5m)}>80\",
                        \"priority\": 3,
                        \"status\": 0
                    },
                    {
                        \"description\": \"High memory utilization\",
                        \"expression\": \"{Linux by Zabbix agent:vm.memory.util.avg(5m)}>90\",
                        \"priority\": 3,
                        \"status\": 0
                    },
                    {
                        \"description\": \"Low disk space\",
                        \"expression\": \"{Linux by Zabbix agent:vfs.fs.util.avg(5m)}>90\",
                        \"priority\": 3,
                        \"status\": 0
                    }
                ]
            },
            \"auth\": \"$auth_token\",
            \"id\": 1
        }" \
        "$ZABBIX_URL"
}

# Function to list existing templates
list_templates() {
    local auth_token="$1"
    
    echo "Existing templates:"
    curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "{
            \"jsonrpc\": \"2.0\",
            \"method\": \"template.get\",
            \"params\": {
                \"output\": [\"host\", \"name\"],
                \"filter\": {\"status\": \"3\"}
            },
            \"auth\": \"$auth_token\",
            \"id\": 1
        }" \
        "$ZABBIX_URL" | jq -r '.result[] | "\(.host) - \(.name)"'
}

# Main execution
echo "Getting authentication token..."
AUTH_TOKEN=$(get_auth_token)

if [ "$AUTH_TOKEN" = "null" ] || [ -z "$AUTH_TOKEN" ]; then
    echo "Failed to get authentication token"
    exit 1
fi

echo "Authentication successful"

echo "Listing existing templates..."
list_templates "$AUTH_TOKEN"

echo "Creating Linux template..."
create_linux_template "$AUTH_TOKEN"

echo "Template creation completed"
