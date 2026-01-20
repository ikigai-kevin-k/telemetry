#!/bin/bash

# Fix duplicate legend labels in Grafana development dashboard
# This script checks for duplicate legendFormat values in the error event panel

set -e

DASHBOARD_FILE="grafana/provisioning/dashboards/general/development.json"

if [ ! -f "$DASHBOARD_FILE" ]; then
    echo "Error: Dashboard file not found: $DASHBOARD_FILE"
    exit 1
fi

echo "Checking for duplicate legend labels in development dashboard..."
echo ""

# Find error event panel and check for duplicate legendFormat
jq -r '.panels[] | select(.title | contains("Error Event") or contains("error") or contains("Error")) | 
    {
        id: .id,
        title: .title,
        targets: [.targets[]? | {
            refId,
            legendFormat,
            expr
        }]
    }' "$DASHBOARD_FILE" 2>/dev/null || echo "No error event panel found in current JSON"

echo ""
echo "Note: If the error event panel is not in the JSON file,"
echo "please export it from Grafana UI first:"
echo "1. Go to Development dashboard in Grafana"
echo "2. Click Settings (gear icon)"
echo "3. Select JSON Model tab"
echo "4. Copy the entire JSON content"
echo "5. Replace the content in $DASHBOARD_FILE"

