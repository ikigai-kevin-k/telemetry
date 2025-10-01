#!/bin/bash

# Start Grafana Webhook Service
# This service receives alerts from Grafana and triggers API calls

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WEBHOOK_SERVICE="$SCRIPT_DIR/grafana_webhook_service.py"
LOG_FILE="$SCRIPT_DIR/webhook_service.log"
PID_FILE="$SCRIPT_DIR/webhook_service.pid"

echo "==============================================="
echo "Starting Grafana Webhook Service..."
echo "==============================================="

# Check if Python3 is available
if ! command -v python3 &> /dev/null; then
    echo "Error: python3 is not installed"
    exit 1
fi

# Check if Flask is installed
if ! python3 -c "import flask" &> /dev/null; then
    echo "Flask is not installed. Installing..."
    pip3 install flask requests
fi

# Check if service is already running
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    if ps -p "$OLD_PID" > /dev/null 2>&1; then
        echo "Webhook service is already running (PID: $OLD_PID)"
        echo "To restart, run: ./stop-webhook-service.sh && ./start-webhook-service.sh"
        exit 1
    else
        echo "Removing stale PID file"
        rm -f "$PID_FILE"
    fi
fi

# Make webhook service executable
chmod +x "$WEBHOOK_SERVICE"

# Start the service in background
echo "Starting webhook service..."
nohup python3 "$WEBHOOK_SERVICE" >> "$LOG_FILE" 2>&1 &
SERVICE_PID=$!

# Save PID
echo $SERVICE_PID > "$PID_FILE"

# Wait a moment and check if it started successfully
sleep 2

if ps -p "$SERVICE_PID" > /dev/null 2>&1; then
    echo ""
    echo "==============================================="
    echo "✓ Webhook service started successfully!"
    echo "==============================================="
    echo ""
    echo "Service Information:"
    echo "- PID: $SERVICE_PID"
    echo "- Webhook URL: http://localhost:5000/webhook/grafana"
    echo "- Health Check: http://localhost:5000/health"
    echo "- Log File: $LOG_FILE"
    echo ""
    echo "Useful commands:"
    echo "- View logs: tail -f $LOG_FILE"
    echo "- Stop service: ./stop-webhook-service.sh"
    echo "- Check status: ps -p $SERVICE_PID"
    echo ""
    echo "Test webhook:"
    echo "  curl -X POST http://localhost:5000/test -H 'Content-Type: application/json' -d '{\"tableId\": \"ARO-001\", \"status\": \"down\"}'"
    echo ""
else
    echo ""
    echo "Error: Failed to start webhook service"
    echo "Check log file: $LOG_FILE"
    rm -f "$PID_FILE"
    exit 1
fi

