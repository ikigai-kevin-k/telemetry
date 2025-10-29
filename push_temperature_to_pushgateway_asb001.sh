#!/bin/bash

# Push CPU temperature to Prometheus Pushgateway for ASB-001-1
# - Reads temperature via sensors -> jq
# - Pushes as a Gauge metric to Pushgateway under job=agent_temperature

set -euo pipefail

PUSHGATEWAY_URL=${PUSHGATEWAY_URL:-"http://100.64.0.113:9091"}
JOB_NAME=${JOB_NAME:-"agent_temperature"}
INSTANCE_LABEL=${INSTANCE_LABEL:-"GC-ASB-001-1-agent"}
METRIC_NAME=${METRIC_NAME:-"system_temperature_celsius"}
INTERVAL_SECONDS=${INTERVAL_SECONDS:-10}

function read_temperature() {
  local value
  value=$(sensors -j 2>/dev/null | jq -r '..|.temp1_input? // empty' | head -n1)
  if [[ -z "$value" || "$value" == "null" || "$value" == "" ]]; then
    return 1
  fi
  # Normalize to decimal with up to 3 decimals
  printf '%.3f' "$value"
}

function push_metric() {
  local temperature_value="$1"
  
  echo "# HELP ${METRIC_NAME} Current system temperature in Celsius" > /tmp/metrics-asb001.txt
  echo "# TYPE ${METRIC_NAME} gauge" >> /tmp/metrics-asb001.txt
  echo "${METRIC_NAME}{instance=\"${INSTANCE_LABEL}\"} ${temperature_value}" >> /tmp/metrics-asb001.txt

  curl -sf \
    -X POST \
    --data-binary @/tmp/metrics-asb001.txt \
    "${PUSHGATEWAY_URL}/metrics/job/${JOB_NAME}" >/dev/null
}

echo "Starting temperature exporter -> ${PUSHGATEWAY_URL} as job=${JOB_NAME}, instance=${INSTANCE_LABEL}"

while true; do
  if temp=$(read_temperature); then
    push_metric "$temp" || echo "[warn] failed to push metric"
  else
    echo "[warn] temperature not available from sensors"
  fi
  sleep "$INTERVAL_SECONDS"
done
