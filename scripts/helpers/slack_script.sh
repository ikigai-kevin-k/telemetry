#!/bin/bash

# Slack notification script for Zabbix
# Parameters: $1=webhook_url $2=subject $3=message

WEBHOOK_URL="$1"
SUBJECT="$2"
MESSAGE="$3"

# Log for debugging
echo "$(date): Webhook: $WEBHOOK_URL" >> /tmp/slack.log
echo "$(date): Subject: $SUBJECT" >> /tmp/slack.log
echo "$(date): Message: $MESSAGE" >> /tmp/slack.log

# Create simple JSON payload
PAYLOAD="{\"text\":\"🚨 Zabbix Alert: $SUBJECT - $MESSAGE\"}"

# Send to Slack using wget with verbose output for debugging
wget --post-data="$PAYLOAD" \
     --header="Content-Type: application/json" \
     --timeout=30 \
     --tries=3 \
     -O- "$WEBHOOK_URL" >> /tmp/slack.log 2>&1

RESULT=$?

if [ $RESULT -eq 0 ]; then
    echo "$(date): Slack notification sent successfully" >> /tmp/slack.log
    echo "Slack notification sent successfully"
    exit 0
else
    echo "$(date): Failed to send Slack notification (exit code: $RESULT)" >> /tmp/slack.log
    echo "Failed to send Slack notification"
    exit 1
fi
