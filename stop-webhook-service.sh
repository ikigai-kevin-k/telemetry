#!/bin/bash

# Stop Grafana Webhook Service

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_FILE="$SCRIPT_DIR/webhook_service.pid"

echo "Stopping Grafana Webhook Service..."

if [ ! -f "$PID_FILE" ]; then
    echo "PID file not found. Service may not be running."
    exit 1
fi

PID=$(cat "$PID_FILE")

if ps -p "$PID" > /dev/null 2>&1; then
    echo "Stopping service (PID: $PID)..."
    kill "$PID"
    
    # Wait for process to stop
    for i in {1..10}; do
        if ! ps -p "$PID" > /dev/null 2>&1; then
            echo "✓ Webhook service stopped successfully!"
            rm -f "$PID_FILE"
            exit 0
        fi
        sleep 1
    done
    
    # Force kill if still running
    echo "Service did not stop gracefully, forcing..."
    kill -9 "$PID" 2>/dev/null
    rm -f "$PID_FILE"
    echo "✓ Webhook service forcefully stopped!"
else
    echo "Service is not running (stale PID file)"
    rm -f "$PID_FILE"
fi

