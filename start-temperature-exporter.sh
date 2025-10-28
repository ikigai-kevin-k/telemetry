#!/bin/bash

# Start the temperature exporter in background on this agent

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PUSHGATEWAY_URL=${PUSHGATEWAY_URL:-"http://100.64.0.113:9091"}
JOB_NAME=${JOB_NAME:-"agent_temperature"}
INSTANCE_LABEL=${INSTANCE_LABEL:-"GC-ARO-002-1-agent"}
INTERVAL_SECONDS=${INTERVAL_SECONDS:-10}

CMD="PUSHGATEWAY_URL=${PUSHGATEWAY_URL} JOB_NAME=${JOB_NAME} INSTANCE_LABEL=${INSTANCE_LABEL} INTERVAL_SECONDS=${INTERVAL_SECONDS} bash \"${SCRIPT_DIR}/push_temperature_to_pushgateway.sh\""

echo "Launching temperature exporter..."
nohup bash -c "$CMD" >/tmp/temperature-exporter.out 2>/tmp/temperature-exporter.err &
PID=$!
echo $PID >/tmp/temperature-exporter.pid
echo "Temperature exporter started with PID $PID"
echo "Logs: /tmp/temperature-exporter.out, /tmp/temperature-exporter.err"


