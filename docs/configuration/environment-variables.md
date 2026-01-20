# Environment Variables

## Required Variables

### Server IP

```bash
export SERVER_IP=100.64.0.113
```

### BytePlus Credentials

Create `byteplus-credentials.env`:

```bash
BYTEPLUS_ACCESS_KEY=your_access_key
BYTEPLUS_SECRET_KEY=your_secret_key
```

## Optional Variables

### Slack Webhook

For Slack alerts:

```bash
export SLACK_WEBHOOK_URL=https://hooks.slack.com/services/your/webhook/url
```

Or create `.env` file:

```bash
# Create .env file
cat > .env << EOF
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/TEAM/SLACK_WEBHOOK_URL
EOF
```

### Getting Slack Webhook URL

1. Go to https://api.slack.com/apps
2. Create a new app or select existing app
3. Go to "Incoming Webhooks"
4. Enable incoming webhooks
5. Add new webhook to workspace
6. Select the channel for notifications
7. Copy the webhook URL

## Security Notes

- Never commit the `.env` file to version control
- Keep your webhook URLs and credentials secure
- Consider rotating credentials periodically
- Use environment variables in production deployments




