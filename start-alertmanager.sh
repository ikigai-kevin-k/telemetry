#!/bin/bash

# Start AlertManager with dynamic webhook URL replacement
# This script replaces the PLACEHOLDER with the actual webhook URL from .env

if [ -f .env ]; then
    source .env
    echo "Using webhook URL from .env file"
else
    echo "No .env file found, using placeholder"
    export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/PLACEHOLDER"
fi

# Create temporary alertmanager config with real webhook URL
sed "s|PLACEHOLDER|${SLACK_WEBHOOK_URL#https://hooks.slack.com/services/}|g" alertmanager.yml > alertmanager-temp.yml

# Start AlertManager with the temporary config
docker run -d \
    --name kevin-telemetry-alertmanager-temp \
    --network telemetry_monitoring \
    -p 9093:9093 \
    -v "$(pwd)/alertmanager-temp.yml:/etc/alertmanager/alertmanager.yml" \
    -v alertmanager_data:/alertmanager \
    prom/alertmanager:latest \
    --config.file=/etc/alertmanager/alertmanager.yml \
    --storage.path=/alertmanager \
    --web.external-url=http://100.64.0.113:9093

echo "AlertManager started with webhook URL: ${SLACK_WEBHOOK_URL}"
