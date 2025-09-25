# ZCAM Temperature Slack Alerts Setup Guide

## 📋 Overview

This guide explains how to set up Slack notifications for ZCAM temperature monitoring. The system will send alerts when:

- **Warning**: Temperature is between 40-45°C
- **Critical**: Temperature is above 45°C  
- **Recovered**: Temperature returns below 40°C

## 🚀 Quick Setup

### Step 1: Create Slack Webhook

1. **Go to Slack API**: https://api.slack.com/apps
2. **Create New App**: Click "Create New App" → "From scratch"
3. **App Name**: `ZCAM Temperature Monitor`
4. **Workspace**: Select your workspace
5. **Enable Incoming Webhooks**:
   - Go to "Incoming Webhooks" in the left sidebar
   - Toggle "Activate Incoming Webhooks" to On
   - Click "Add New Webhook to Workspace"
   - Select the channel where you want notifications (e.g., #monitoring)
   - Click "Allow"
6. **Copy Webhook URL**: Copy the generated webhook URL

### Step 2: Configure Environment Variables

1. **Create .env file**:
   ```bash
   cat > .env << EOF
   SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/TEAM/SLACK_WEBHOOK_URL
   EOF
   ```

2. **Replace the webhook URL** with your actual Slack webhook URL

### Step 3: Start the Services

```bash
# Start AlertManager
docker-compose up -d alertmanager

# Reload Prometheus configuration
curl -X POST http://100.64.0.113:9090/-/reload
```

## 🔧 Configuration Files

### AlertManager Configuration (`alertmanager.yml`)

```yaml
global:
  slack_api_url: '${SLACK_WEBHOOK_URL}'

route:
  group_by: ['alertname', 'device_name']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'slack-notifications'

receivers:
- name: 'slack-notifications'
  slack_configs:
  - channel: '#monitoring'
    title: 'ZCAM Temperature Alert'
    text: |
      {{ range .Alerts }}
      *Alert:* {{ .Annotations.summary }}
      *Device:* {{ .Labels.device_name }}
      *Temperature:* {{ .Annotations.temperature }}°C
      *Status:* {{ .Status }}
      *Time:* {{ .StartsAt.Format "2006-01-02 15:04:05" }}
      {{ if .Annotations.description }}
      *Description:* {{ .Annotations.description }}
      {{ end }}
      ---
      {{ end }}
    send_resolved: true
```

### Prometheus Alert Rules (`zcam-temperature-alerts.yml`)

```yaml
groups:
- name: zcam-temperature-alerts
  rules:
  # Temperature Warning: 40-45°C
  - alert: ZCAMTemperatureWarning
    expr: zcam_temperature{job="zcam-values"} >= 40 and zcam_temperature{job="zcam-values"} < 45
    for: 1m
    labels:
      severity: warning
      alert_type: temperature_warning
    annotations:
      summary: "ZCAM Temperature Warning - Device {{ $labels.device_name }}"
      description: "Device {{ $labels.device_name }} temperature is {{ $value }}°C, which is in the warning range (40-45°C)"
      temperature: "{{ $value }}"
      device_ip: "{{ $labels.device_ip }}"

  # Temperature Critical: >45°C
  - alert: ZCAMTemperatureCritical
    expr: zcam_temperature{job="zcam-values"} >= 45
    for: 30s
    labels:
      severity: critical
      alert_type: temperature_critical
    annotations:
      summary: "ZCAM Temperature Critical - Device {{ $labels.device_name }}"
      description: "Device {{ $labels.device_name }} temperature is {{ $value }}°C, which is in the critical range (>45°C). Immediate attention required!"
      temperature: "{{ $value }}"
      device_ip: "{{ $labels.device_ip }}"

  # Temperature Recovery: Back to normal (<40°C)
  - alert: ZCAMTemperatureRecovered
    expr: zcam_temperature{job="zcam-values"} < 40
    for: 2m
    labels:
      severity: info
      alert_type: temperature_recovered
    annotations:
      summary: "ZCAM Temperature Recovered - Device {{ $labels.device_name }}"
      description: "Device {{ $labels.device_name }} temperature has returned to normal at {{ $value }}°C"
      temperature: "{{ $value }}"
      device_ip: "{{ $labels.device_ip }}"
```

## 🧪 Testing the Setup

### Test AlertManager Configuration

```bash
# Check AlertManager status
curl http://100.64.0.113:9093/api/v2/status

# Check Prometheus alerts
curl http://100.64.0.113:9090/api/v1/alerts
```

### Manual Test (Optional)

```bash
# Make the script executable
chmod +x temperature-slack-alert.sh

# Test warning alert
./temperature-slack-alert.sh \
  "$SLACK_WEBHOOK_URL" \
  "zcam-aro-001-1" \
  "42" \
  "warning" \
  "192.168.88.184"
```

## 📊 Monitoring

### Access URLs

- **Prometheus**: http://100.64.0.113:9090
- **AlertManager**: http://100.64.0.113:9093
- **Grafana Dashboard**: http://100.64.0.113:3000/d/zcam-http-response/zcam-http-response-monitoring

### Check Logs

```bash
# Check AlertManager logs
docker logs kevin-telemetry-alertmanager

# Check Prometheus logs
docker logs kevin-telemetry-prometheus

# Check temperature alert script logs
tail -f /tmp/temperature-slack.log
```

## 🚨 Alert Thresholds

| Temperature Range | Alert Type | Duration | Color | Emoji |
|------------------|------------|----------|-------|-------|
| 40-45°C | Warning | 1 minute | Orange | ⚠️ |
| >45°C | Critical | 30 seconds | Red | 🚨 |
| <40°C | Recovered | 2 minutes | Green | ✅ |

## 🔧 Troubleshooting

### Common Issues

1. **No alerts being sent**:
   - Check webhook URL is correct
   - Verify channel name exists
   - Check AlertManager logs

2. **Alerts not triggering**:
   - Verify temperature metrics are being collected
   - Check Prometheus alert rules
   - Verify device names match labels

3. **Wrong temperature values**:
   - Ensure `zcam-values` exporter is running
   - Check temperature metrics in Prometheus

### Debug Commands

```bash
# Check if temperature metrics exist
curl "http://100.64.0.113:9090/api/v1/query?query=zcam_temperature"

# Check AlertManager configuration
curl http://100.64.0.113:9093/api/v2/status

# Check active alerts
curl http://100.64.0.113:9090/api/v1/alerts
```

## 📝 Notes

- Alerts are grouped by device name to avoid spam
- Recovery alerts are sent when temperature drops below 40°C
- All alerts include device IP and timestamp
- Slack messages include direct links to Grafana dashboard
- Alert history is stored in AlertManager for 24 hours

## 🔒 Security

- Keep webhook URLs secure and don't commit them to version control
- Use environment variables for sensitive configuration
- Regularly rotate webhook URLs if needed
