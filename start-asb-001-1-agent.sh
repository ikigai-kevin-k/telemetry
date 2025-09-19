#!/bin/bash

# Start ASB-001-1 Agent with dynamic SBO001 log file monitoring
# This script ensures the latest SBO001 log file is available before starting the agent

AGENT_NAME="GC-ASB-001-1-agent"
LOG_DIR="/home/rnd/studio-sdp-roulette/logs"
COMPOSE_FILE="docker-compose-GC-ASB-001-1-agent.yml"

echo "Starting Telemetry Agent: $AGENT_NAME"
echo "Monitoring SBO001 logs in: $LOG_DIR"
echo ""

# Check if log directory exists
if [ ! -d "$LOG_DIR" ]; then
    echo "Warning: Log directory $LOG_DIR does not exist"
    echo "Creating log directory..."
    mkdir -p "$LOG_DIR"
fi

# Check for existing SBO001 log files
echo "Checking for SBO001 log files..."
SBO_FILES=$(find "$LOG_DIR" -name "SBO001_*.log" -type f 2>/dev/null)

if [ -z "$SBO_FILES" ]; then
    echo "Warning: No SBO001_*.log files found in $LOG_DIR"
    echo "The agent will start but won't collect SBO001 logs until files are available"
else
    echo "Found SBO001 log files:"
    echo "$SBO_FILES"
    
    # Get the latest log file
    if [ -f "./scripts/get-latest-sbo-log.sh" ]; then
        echo ""
        echo "Latest log file info:"
        ./scripts/get-latest-sbo-log.sh "$LOG_DIR" --info
    fi
fi

echo ""
echo "Starting Docker containers..."

# Stop any existing containers
docker compose -f "$COMPOSE_FILE" down 2>/dev/null

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
    echo "Log monitoring info:"
    echo "  - SBO001 logs: $LOG_DIR/SBO001_*.log (dynamic pattern)"
    echo "  - Promtail will automatically detect new SBO001 log files"
    echo "  - Log data sent to Loki server at: 100.64.0.113:3100"
else
    echo "❌ Failed to start $AGENT_NAME"
    exit 1
fi
