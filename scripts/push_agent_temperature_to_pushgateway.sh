#!/bin/bash

# Script to collect temperature data from Zabbix agents and push to Pushgateway
# This script collects system.temperature from all agents and pushes as system_temperature_celsius metric

set -eo pipefail

# Configuration
PUSHGATEWAY_URL="${PUSHGATEWAY_URL:-http://localhost:9091}"
ZABBIX_SERVER_CONTAINER="kevin-telemetry-zabbix-server"
JOB_NAME="agent_temperature"
ZABBIX_PORT="10050"

# Agent configuration: hostname=IP
declare -A AGENTS=(
    ["GC-ARO-001-1-agent"]="100.64.0.167"
    ["GC-aro12-agent"]="100.64.0.149"
    ["GC-ARO-002-1-agent"]="100.64.0.143"
    ["GC-ARO-002-2-agent"]="100.64.0.144"
    ["GC-ASB-001-1-agent"]="100.64.0.166"
)

# Function to get temperature from Zabbix agent
get_temperature() {
    local hostname=$1
    local ip=$2
    
    # Use zabbix_get from Zabbix server container with timeout
    # Capture both stdout and stderr, and ignore docker exec errors
    local result=$(timeout 5 docker exec "$ZABBIX_SERVER_CONTAINER" zabbix_get \
        -s "$ip" \
        -p "$ZABBIX_PORT" \
        -k "system.temperature" 2>&1 || echo "")
    
    # Check if result is valid (not empty, not ZBX_NOTSUPPORTED, and is a number)
    if [ -n "$result" ] && \
       [[ ! "$result" =~ ZBX_NOTSUPPORTED ]] && \
       [[ ! "$result" =~ Unknown ]] && \
       [[ "$result" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        echo "$result"
        return 0
    else
        echo ""
        return 1
    fi
}

# Function to push metric to Pushgateway
push_metric() {
    local hostname=$1
    local temperature=$2
    
    local url="${PUSHGATEWAY_URL}/metrics/job/${JOB_NAME}/instance/${hostname}"
    # Pushgateway requires HELP and TYPE definitions for gauge metrics
    local metric_data="# HELP system_temperature_celsius Current system temperature in Celsius"$'\n'
    metric_data+="# TYPE system_temperature_celsius gauge"$'\n'
    metric_data+="system_temperature_celsius{instance=\"${hostname}\"} ${temperature}"$'\n'
    
    # Push metric using curl
    local http_code=$(curl -s -w "%{http_code}" -o /dev/null \
        -X POST \
        --data-binary "$metric_data" \
        "$url" 2>&1)
    
    if [ "$http_code" = "200" ]; then
        echo "✅ Successfully pushed: ${hostname} = ${temperature}°C"
        return 0
    else
        echo "❌ Failed to push ${hostname}: HTTP ${http_code}"
        return 1
    fi
}

# Main execution
main() {
    echo "🌡️  Collecting temperature data from Zabbix agents and pushing to Pushgateway..."
    echo "Pushgateway URL: ${PUSHGATEWAY_URL}"
    echo ""
    
    local success_count=0
    local fail_count=0
    
    # Process agents in a defined order to ensure all are processed
    local agent_list=("GC-ARO-001-1-agent" "GC-aro12-agent" "GC-ARO-002-1-agent" "GC-ARO-002-2-agent" "GC-ASB-001-1-agent")
    
    for hostname in "${agent_list[@]}"; do
        ip="${AGENTS[$hostname]}"
        
        if [ -z "$ip" ]; then
            echo "⚠️  Skipping ${hostname}: IP not configured"
            continue
        fi
        
        echo -n "Collecting temperature from ${hostname} (${ip})... "
        
        # Get temperature (ignore errors to continue processing other agents)
        # Temporarily disable set -e to allow continue on errors
        set +e
        temperature=$(get_temperature "$hostname" "$ip" 2>/dev/null || echo "")
        local temp_result=$?
        set -e
        
        if [ -z "$temperature" ] || [ $temp_result -ne 0 ]; then
            echo "❌ Failed to get temperature (metric not supported or agent unavailable)"
            ((fail_count++))
            continue
        fi
        
        echo -n "${temperature}°C → "
        
        # Push to Pushgateway (temporarily disable set -e to allow continue on errors)
        set +e
        if push_metric "$hostname" "$temperature"; then
            ((success_count++))
        else
            ((fail_count++))
        fi
        set -e
    done
    
    echo ""
    echo "📊 Summary: ${success_count} successful, ${fail_count} failed"
    
    if [ $fail_count -eq 0 ]; then
        echo "✅ All temperature metrics pushed successfully!"
        exit 0
    else
        echo "⚠️  Some metrics failed to push"
        exit 1
    fi
}

# Run main function
main

