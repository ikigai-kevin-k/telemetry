#!/bin/bash

# Start temperature exporter for ARO-002-2 in background
# This script starts the temperature monitoring service and saves the PID

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PUSH_SCRIPT="${SCRIPT_DIR}/push_temperature_to_pushgateway_aro002_2.sh"
PID_FILE="/tmp/temperature-exporter-aro002-2.pid"
OUT_LOG="/tmp/temperature-exporter-aro002-2.out"
ERR_LOG="/tmp/temperature-exporter-aro002-2.err"

# Check if script exists
if [[ ! -f "$PUSH_SCRIPT" ]]; then
  echo "Error: Temperature push script not found at $PUSH_SCRIPT"
  exit 1
fi

# Check if already running
if [[ -f "$PID_FILE" ]]; then
  OLD_PID=$(cat "$PID_FILE")
  if ps -p "$OLD_PID" > /dev/null 2>&1; then
    echo "Temperature exporter is already running (PID: $OLD_PID)"
    exit 0
  else
    echo "Removing stale PID file"
    rm -f "$PID_FILE"
  fi
fi

# Make script executable
chmod +x "$PUSH_SCRIPT"

# Start in background
nohup bash "$PUSH_SCRIPT" > "$OUT_LOG" 2> "$ERR_LOG" &
NEW_PID=$!

# Save PID
echo "$NEW_PID" > "$PID_FILE"

echo "Temperature exporter started (PID: $NEW_PID)"
echo "Output log: $OUT_LOG"
echo "Error log: $ERR_LOG"
echo "PID file: $PID_FILE"

