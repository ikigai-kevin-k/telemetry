#!/bin/bash

# Temperature Slack Alert Script for ZCAM devices
# Usage: ./temperature-slack-alert.sh <webhook_url> <device_name> <temperature> <status> <device_ip>

WEBHOOK_URL="$1"
DEVICE_NAME="$2"
TEMPERATURE="$3"
STATUS="$4"  # warning, critical, recovered
DEVICE_IP="$5"

# Set colors and emojis based on status
case $STATUS in
    "warning")
        COLOR="#ff9900"  # Orange
        EMOJI="⚠️"
        TITLE="Temperature Warning"
        ;;
    "critical")
        COLOR="#ff0000"  # Red
        EMOJI="🚨"
        TITLE="Temperature Critical"
        ;;
    "recovered")
        COLOR="#00ff00"  # Green
        EMOJI="✅"
        TITLE="Temperature Recovered"
        ;;
    *)
        COLOR="#808080"  # Gray
        EMOJI="ℹ️"
        TITLE="Temperature Alert"
        ;;
esac

# Create timestamp
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Create detailed Slack message with blocks
PAYLOAD=$(cat <<EOF
{
  "channel": "#monitoring",
  "username": "ZCAM Temperature Monitor",
  "icon_emoji": ":thermometer:",
  "attachments": [
    {
      "color": "$COLOR",
      "title": "$EMOJI $TITLE - $DEVICE_NAME",
      "title_link": "http://100.64.0.113:3000/d/zcam-http-response/zcam-http-response-monitoring",
      "fields": [
        {
          "title": "Device Name",
          "value": "$DEVICE_NAME",
          "short": true
        },
        {
          "title": "IP Address",
          "value": "$DEVICE_IP",
          "short": true
        },
        {
          "title": "Current Temperature",
          "value": "${TEMPERATURE}°C",
          "short": true
        },
        {
          "title": "Status",
          "value": "$(echo $STATUS | tr '[:lower:]' '[:upper:]')",
          "short": true
        },
        {
          "title": "Timestamp",
          "value": "$TIMESTAMP",
          "short": true
        }
      ],
      "footer": "ZCAM Monitoring System",
      "footer_icon": "https://platform.slack-edge.com/img/default_application_icon.png",
      "ts": $(date +%s)
    }
  ]
}
EOF
)

# Log for debugging
echo "$(date): Sending $STATUS alert for $DEVICE_NAME at ${TEMPERATURE}°C" >> /tmp/temperature-slack.log

# Send to Slack
RESULT=$(curl -s -w "%{http_code}" -o /tmp/slack_response.log \
    -X POST \
    -H 'Content-type: application/json' \
    --data "$PAYLOAD" \
    "$WEBHOOK_URL")

HTTP_CODE=$(echo $RESULT | tail -c 4)

if [ "$HTTP_CODE" = "200" ]; then
    echo "$(date): Slack notification sent successfully for $DEVICE_NAME" >> /tmp/temperature-slack.log
    echo "✅ Slack notification sent successfully for $DEVICE_NAME"
    exit 0
else
    echo "$(date): Failed to send Slack notification (HTTP $HTTP_CODE) for $DEVICE_NAME" >> /tmp/temperature-slack.log
    echo "❌ Failed to send Slack notification (HTTP $HTTP_CODE)"
    exit 1
fi
