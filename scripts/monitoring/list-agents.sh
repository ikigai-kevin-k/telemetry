#!/bin/bash

# List all configured agents
# Usage: ./list-agents.sh

echo "=== Telemetry Agents Status ==="
echo ""

# Check if agent-configs directory exists
if [ ! -d "agent-configs" ]; then
    echo "No agent configurations found."
    echo "Run './start-agent.sh <agent_name> <agent_ip>' to create a new agent."
    exit 0
fi

echo "Configured Agents:"
echo "=================="

# List all agent configuration files
for config_file in agent-configs/*.yml; do
    if [ -f "$config_file" ]; then
        agent_name=$(basename "$config_file" .yml)
        
        # Extract agent information from config file
        agent_ip=$(grep "agent_ip:" "$config_file" | cut -d'"' -f2)
        created_at=$(grep "created_at:" "$config_file" | cut -d'"' -f2)
        
        echo "Agent: $agent_name"
        echo "  IP: $agent_ip"
        echo "  Created: $created_at"
        
        # Check if containers are running
        promtail_container="telemetry-promtail-${agent_name}"
        zabbix_container="telemetry-zabbix-agent-${agent_name}"
        
        promtail_status=$(docker ps --filter "name=$promtail_container" --format "table {{.Names}}\t{{.Status}}" | grep -v "NAMES" || echo "Not running")
        zabbix_status=$(docker ps --filter "name=$zabbix_container" --format "table {{.Names}}\t{{.Status}}" | grep -v "NAMES" || echo "Not running")
        
        echo "  Promtail Status: $promtail_status"
        echo "  Zabbix Status: $zabbix_status"
        echo ""
    fi
done

echo "=== Docker Compose Files ==="
echo ""

# List all docker-compose files for agents
for compose_file in docker-compose-*.yml; do
    if [ -f "$compose_file" ] && [ "$compose_file" != "docker-compose.yml" ] && [ "$compose_file" != "docker-compose.agent.yml" ]; then
        agent_name=$(echo "$compose_file" | sed 's/docker-compose-\(.*\)\.yml/\1/')
        echo "Docker Compose: $compose_file (Agent: $agent_name)"
    fi
done

echo ""
echo "=== Usage ==="
echo "Start agent: ./start-agent.sh <agent_name> <agent_ip>"
echo "Stop agent: docker compose -f docker-compose-<agent_name>.yml down"
echo "View logs: docker compose -f docker-compose-<agent_name>.yml logs -f"
