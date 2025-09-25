# Environment Variables Setup Guide

## Slack Webhook Configuration

To set up Slack notifications for temperature alerts, you need to configure the `SLACK_WEBHOOK_URL` environment variable.

### Step 1: Create .env file

Create a `.env` file in the project root:

```bash
# Create .env file
cat > .env << EOF
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/TEAM/SLACK_WEBHOOK_URL
EOF
```

### Step 2: Get Slack Webhook URL

1. Go to https://api.slack.com/apps
2. Create a new app or select existing app
3. Go to "Incoming Webhooks"
4. Enable incoming webhooks
5. Add new webhook to workspace
6. Select the channel for notifications
7. Copy the webhook URL

### Step 3: Update .env file

Replace the placeholder URL with your actual webhook URL:

```bash
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/TEAM/SLACK_WEBHOOK_URL
```

### Step 4: Restart AlertManager

```bash
# Restart AlertManager to load the environment variable
docker-compose restart alertmanager
```

### Security Notes

- Never commit the `.env` file to version control
- Keep your webhook URL secure
- Consider rotating webhook URLs periodically

### Testing

You can test the Slack integration by triggering a test alert:

```bash
# Test warning alert
./temperature-slack-alert.sh \
  "$SLACK_WEBHOOK_URL" \
  "zcam-aro-001-1" \
  "42" \
  "warning" \
  "192.168.88.184"
```