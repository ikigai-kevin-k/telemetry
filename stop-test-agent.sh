#!/bin/bash

# Stop Test Agent Mode
# This script stops the test Promtail agent

echo "Stopping Telemetry Test Agent..."

# Check if docker compose is available (prefer v2 over v1)
if docker compose version &> /dev/null; then
    DOCKER_COMPOSE_CMD="docker compose"
elif command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE_CMD="docker-compose"
else
    echo "Error: Neither docker compose nor docker-compose is available"
    exit 1
fi

DOCKER_COMPOSE_FILE="docker-compose-test-agent.yml"

$DOCKER_COMPOSE_CMD -f "$DOCKER_COMPOSE_FILE" down

if [ $? -eq 0 ]; then
    echo "✓ Test Agent services stopped successfully!"
else
    echo "Error: Failed to stop test agent services"
    exit 1
fi

