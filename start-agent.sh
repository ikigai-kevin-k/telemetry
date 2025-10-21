#!/bin/bash

# Start Agent Mode - Support multiple agents with dynamic configuration
# Usage: ./start-agent.sh <agent_name> <agent_ip>
# Example: ./start-agent.sh GC-asb11-agent 100.64.0.166

# Default values for backward compatibility
DEFAULT_AGENT_NAME="GC-aro12-agent"
DEFAULT_AGENT_IP="100.64.0.149"

# Get parameters from command line or use defaults
AGENT_NAME="${1:-$DEFAULT_AGENT_NAME}"
AGENT_IP="${2:-$DEFAULT_AGENT_IP}"

# Server configuration
SERVER_IP="100.64.0.113"
SERVER_LOKI_PORT="3100"
SERVER_ZABBIX_PORT="10051"

echo "Starting Telemetry Agent Mode..."
echo "Agent Name: $AGENT_NAME"
echo "Agent IP: $AGENT_IP"
echo "Services: Loki Agent (Promtail), Zabbix Agent"
echo "Connecting to Server: $SERVER_IP"
echo ""

# Create agent configs directory if it doesn't exist
mkdir -p agent-configs

# Generate agent configuration file
AGENT_CONFIG_FILE="agent-configs/${AGENT_NAME}.yml"

# Check if agent configuration already exists
if [ ! -f "$AGENT_CONFIG_FILE" ]; then
    echo "Creating new agent configuration: $AGENT_CONFIG_FILE"
    cat > "$AGENT_CONFIG_FILE" << EOF
# Agent Configuration for $AGENT_NAME
# Generated configuration for agent running on $AGENT_IP

agent_name: "$AGENT_NAME"
agent_ip: "$AGENT_IP"
server_ip: "$SERVER_IP"
server_loki_port: "$SERVER_LOKI_PORT"
server_zabbix_port: "$SERVER_ZABBIX_PORT"
server_zabbix_active_port: "$SERVER_ZABBIX_PORT"

# Container names
promtail_container: "telemetry-promtail-${AGENT_NAME}"
zabbix_container: "telemetry-zabbix-agent-${AGENT_NAME}"

# Network configuration
network_name: "telemetry_monitoring"

# Log files to monitor
log_files:
  - "./mock_sicbo.log:/var/log/mock_sicbo.log"
  - "./server.log:/var/log/server.log"
  - "./tmux-client-3638382.log:/var/log/tmux-client.log"
  - "./sdp.log:/var/log/sdp.log"

# Configuration files
promtail_config: "./promtail-${AGENT_NAME}.yml"
zabbix_config: "./zabbix/agent2-${AGENT_NAME}.conf"

# Docker compose file
docker_compose_file: "./docker-compose-${AGENT_NAME}.yml"

# Created timestamp
created_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
EOF
    echo "Agent configuration created successfully!"
else
    echo "Using existing agent configuration: $AGENT_CONFIG_FILE"
fi

# Generate configuration files for the agent
echo "Generating configuration files for $AGENT_NAME..."

# Generate Promtail configuration
./generate-agent-configs.sh "$AGENT_NAME" "$AGENT_IP"

# Check if docker compose is available
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE_CMD="docker-compose"
elif docker compose version &> /dev/null; then
    DOCKER_COMPOSE_CMD="docker compose"
else
    echo "Error: Neither docker-compose nor docker compose is available"
    exit 1
fi

# Start agent services using generated docker-compose file
DOCKER_COMPOSE_FILE="docker-compose-${AGENT_NAME}.yml"
echo "Starting agent services using $DOCKER_COMPOSE_FILE..."
$DOCKER_COMPOSE_CMD -f "$DOCKER_COMPOSE_FILE" up -d

echo ""
echo "Agent services started successfully!"
echo ""
echo "Agent Configuration:"
echo "- Promtail: Collecting logs and sending to $SERVER_IP:$SERVER_LOKI_PORT"
echo "- Zabbix Agent: Connecting to $SERVER_IP:$SERVER_ZABBIX_PORT"
echo "- Log files being monitored:"
echo "  - /var/log/mock_sicbo.log"
echo "  - /var/log/server.log"
echo "  - /var/log/tmux-client.log"
echo "  - /var/log/sdp.log"
echo ""
echo "To view logs: $DOCKER_COMPOSE_CMD -f $DOCKER_COMPOSE_FILE logs -f"
echo "To stop services: $DOCKER_COMPOSE_CMD -f $DOCKER_COMPOSE_FILE down"
