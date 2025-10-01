#!/bin/bash

# Start Test Agent Mode - Promtail for test logs
# This script starts a dedicated Promtail agent for monitoring test logs
# Usage: 
#   ./start-test-agent.sh              (uses GE server by default)
#   ./start-test-agent.sh tpe          (uses TPE server)
#   ./start-test-agent.sh ge           (explicitly uses GE server)
#   LOKI_SERVER_IP=100.64.0.160 ./start-test-agent.sh  (custom IP)

# Determine server location from argument or environment
SERVER_LOCATION="${1:-ge}"

# Set Loki server IP based on location
if [ ! -z "$LOKI_SERVER_IP" ]; then
    # Use environment variable if provided
    echo "Using custom Loki server IP from environment: $LOKI_SERVER_IP"
elif [ "$SERVER_LOCATION" = "tpe" ]; then
    export LOKI_SERVER_IP="100.64.0.160"
    echo "Using TPE Loki server: $LOKI_SERVER_IP"
elif [ "$SERVER_LOCATION" = "ge" ]; then
    export LOKI_SERVER_IP="100.64.0.113"
    echo "Using GE Loki server: $LOKI_SERVER_IP"
else
    echo "Error: Invalid server location. Use 'tpe' or 'ge'"
    exit 1
fi

LOKI_PORT="3100"

echo "==============================================="
echo "Starting Telemetry Test Agent Mode..."
echo "==============================================="
echo "Agent Name: telemetry-promtail-test-agent"
echo "Log Path: /home/ella/share_folder/srs.log"
echo "Loki Server: $LOKI_SERVER_IP:$LOKI_PORT"
echo ""

# Check if log file exists
LOG_FILE="/home/ella/share_folder/srs.log"
if [ ! -f "$LOG_FILE" ]; then
    echo "Warning: Log file does not exist: $LOG_FILE"
    echo "Creating share_folder directory and log file..."
    mkdir -p /home/ella/share_folder
    touch "$LOG_FILE"
    echo "Log file created: $LOG_FILE"
fi

# Check if docker compose is available (prefer v2 over v1)
if docker compose version &> /dev/null; then
    DOCKER_COMPOSE_CMD="docker compose"
elif command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE_CMD="docker-compose"
else
    echo "Error: Neither docker compose nor docker-compose is available"
    exit 1
fi

# Start test agent services using docker-compose file
DOCKER_COMPOSE_FILE="docker-compose-test-agent.yml"
echo "Starting test agent services using $DOCKER_COMPOSE_FILE..."
echo ""

$DOCKER_COMPOSE_CMD -f "$DOCKER_COMPOSE_FILE" up -d

if [ $? -eq 0 ]; then
    echo ""
    echo "==============================================="
    echo "✓ Test Agent services started successfully!"
    echo "==============================================="
    echo ""
    echo "Configuration:"
    echo "- Container: telemetry-promtail-test-agent"
    echo "- Promtail: Collecting logs and sending to $LOKI_SERVER_IP:$LOKI_PORT"
    echo "- Log file: $LOG_FILE"
    echo "- Job name: srs_test"
    echo "- Instance label: telemetry-promtail-test-agent"
    echo ""
    echo "Useful commands:"
    echo "- View logs: $DOCKER_COMPOSE_CMD -f $DOCKER_COMPOSE_FILE logs -f"
    echo "- Stop service: $DOCKER_COMPOSE_CMD -f $DOCKER_COMPOSE_FILE down"
    echo "- Restart service: $DOCKER_COMPOSE_CMD -f $DOCKER_COMPOSE_FILE restart"
    echo "- Check status: $DOCKER_COMPOSE_CMD -f $DOCKER_COMPOSE_FILE ps"
    echo ""
    echo "To query logs in Grafana/Loki, use:"
    echo "  {job=\"srs_test\", instance=\"telemetry-promtail-test-agent\"}"
    echo ""
else
    echo ""
    echo "Error: Failed to start test agent services"
    exit 1
fi

