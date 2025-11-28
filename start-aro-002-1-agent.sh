#!/bin/bash

# Start ARO-002-1 Agent
# This script starts the telemetry agent for GC-ARO-002-1-agent
# It ensures Docker volumes exist and starts the containers

set -euo pipefail

AGENT_NAME="GC-ARO-002-1-agent"
COMPOSE_FILE="docker-compose-GC-ARO-002-1-agent.yml"
PROJECT_DIR="/home/rnd/telemetry"

# Change to project directory
cd "$PROJECT_DIR" || {
    echo "Error: Cannot change to directory $PROJECT_DIR"
    exit 1
}

echo "Starting Telemetry Agent: $AGENT_NAME"
echo "======================================"
echo ""

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo "Error: Docker daemon is not running"
    echo "Please start Docker daemon first"
    exit 1
fi

# Check if compose file exists
if [ ! -f "$COMPOSE_FILE" ]; then
    echo "Error: Docker compose file not found: $COMPOSE_FILE"
    exit 1
fi

# Ensure Docker volumes exist (they are marked as external: true)
echo "Checking Docker volumes..."
VOLUMES=(
    "telemetry_promtail_aro_002_1_positions"
    "telemetry_promtail_aro_002_1_data"
    "telemetry_zabbix_agent_aro_002_1_data"
)

for volume in "${VOLUMES[@]}"; do
    if ! docker volume inspect "$volume" >/dev/null 2>&1; then
        echo "Creating volume: $volume"
        docker volume create "$volume"
    else
        echo "Volume exists: $volume"
    fi
done

echo ""
echo "Starting Docker containers..."

# Stop any existing containers first (clean start)
docker compose -f "$COMPOSE_FILE" down 2>/dev/null || true

# Wait a moment for clean shutdown
sleep 2

# Start the containers
docker compose -f "$COMPOSE_FILE" up -d

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ $AGENT_NAME started successfully!"
    echo ""
    echo "Services running:"
    docker compose -f "$COMPOSE_FILE" ps
    echo ""
    echo "To view logs:"
    echo "  docker compose -f $COMPOSE_FILE logs -f"
    echo ""
    echo "To stop:"
    echo "  docker compose -f $COMPOSE_FILE down"
    echo ""
    echo "Agent configuration:"
    echo "  - Promtail: Collecting logs and sending to 100.64.0.113:3100"
    echo "  - Zabbix Agent: Connecting to 100.64.0.113:10051"
    echo "  - Hostname: GC-ARO-002-1-agent"
else
    echo "❌ Failed to start $AGENT_NAME"
    exit 1
fi

