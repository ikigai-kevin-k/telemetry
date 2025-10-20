#!/bin/bash

# Zabbix Datasource Diagnostic Script
echo "🔍 Zabbix Datasource Diagnostic"
echo "==============================="

# Test 1: Check if Zabbix datasource is accessible from Grafana
echo "1. Testing Zabbix API accessibility from Grafana container..."
docker exec kevin-telemetry-grafana curl -s "http://localhost:8080/api_jsonrpc.php" -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"user.login","params":{"user":"admin","password":"admin"},"id":1}' | jq -r '.result' 2>/dev/null

if [ $? -eq 0 ]; then
    echo "   ✅ Zabbix API accessible from Grafana container"
else
    echo "   ❌ Zabbix API not accessible from Grafana container"
fi

# Test 2: Check Grafana datasource configuration
echo ""
echo "2. Checking Grafana datasource configuration..."
echo "   Datasource file content:"
docker exec kevin-telemetry-grafana cat /etc/grafana/provisioning/datasources/zabbix.yml

# Test 3: Check if Zabbix plugin is installed
echo ""
echo "3. Checking Zabbix plugin installation..."
docker exec kevin-telemetry-grafana ls -la /var/lib/grafana/plugins/ | grep -i zabbix

# Test 4: Check Grafana logs for datasource errors
echo ""
echo "4. Checking recent Grafana logs for datasource errors..."
docker logs kevin-telemetry-grafana --tail 100 | grep -i "zabbix\|datasource" | tail -10

# Test 5: Test direct Zabbix query
echo ""
echo "5. Testing direct Zabbix query for GC-aro12-agent..."
auth_token=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d '{
        "jsonrpc": "2.0",
        "method": "user.login",
        "params": {
            "user": "admin",
            "password": "admin"
        },
        "id": 1
    }' \
    "http://localhost:8080/api_jsonrpc.php" | jq -r '.result' 2>/dev/null)

if [ "$auth_token" != "null" ] && [ -n "$auth_token" ]; then
    echo "   ✅ Authentication successful"
    
    # Test CPU query
    echo "   Testing CPU query..."
    cpu_response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "{
            \"jsonrpc\": \"2.0\",
            \"method\": \"item.get\",
            \"params\": {
                \"output\": [\"name\", \"key\", \"lastvalue\"],
                \"host\": \"GC-aro12-agent\",
                \"filter\": {
                    \"key\": [\"system.cpu.util\"]
                }
            },
            \"auth\": \"$auth_token\",
            \"id\": 1
        }" \
        "http://localhost:8080/api_jsonrpc.php")
    
    cpu_count=$(echo "$cpu_response" | jq '.result | length' 2>/dev/null)
    if [ "$cpu_count" -gt 0 ]; then
        cpu_value=$(echo "$cpu_response" | jq -r '.result[0].lastvalue' 2>/dev/null)
        echo "   ✅ CPU data found: $cpu_value"
    else
        echo "   ❌ No CPU data found"
    fi
    
    # Test Network query
    echo "   Testing Network query..."
    net_response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "{
            \"jsonrpc\": \"2.0\",
            \"method\": \"item.get\",
            \"params\": {
                \"output\": [\"name\", \"key\", \"lastvalue\"],
                \"host\": \"GC-aro12-agent\",
                \"filter\": {
                    \"key\": [\"net.if.in[eth0]\", \"net.if.out[eth0]\"]
                }
            },
            \"auth\": \"$auth_token\",
            \"id\": 1
        }" \
        "http://localhost:8080/api_jsonrpc.php")
    
    net_count=$(echo "$net_response" | jq '.result | length' 2>/dev/null)
    if [ "$net_count" -gt 0 ]; then
        echo "   ✅ Network data found: $net_count items"
        echo "$net_response" | jq -r '.result[] | "     - \(.name) (\(.key)): \(.lastvalue)"' 2>/dev/null
    else
        echo "   ❌ No Network data found"
    fi
else
    echo "   ❌ Authentication failed"
fi

echo ""
echo "🎯 Diagnostic Complete!"
echo "======================"
echo ""
echo "💡 If Zabbix API is accessible but Grafana shows 'No data':"
echo "1. Check if Zabbix datasource is properly configured in Grafana UI"
echo "2. Test the datasource connection in Grafana UI"
echo "3. Verify the dashboard queries are using the correct datasource UID"
echo "4. Check if the time range in Grafana covers the data collection period"
