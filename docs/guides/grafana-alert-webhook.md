# Grafana Alert Webhook Setup Guide

## 📋 Overview

This system monitors SRS logs from Loki and triggers an API call when `okbps=0,0,0` is detected, indicating no data transmission from the camera/encoder.

## 🏗️ Architecture

```
SRS Log → Promtail → Loki → Grafana Alert Rule → Webhook Service → API (localhost:8085)
```

**Flow:**
1. Promtail monitors `/home/ella/share_folder/srs.log`
2. Sends logs to Loki
3. Grafana alert rule queries Loki for `okbps=0,0,0`
4. When detected, Grafana sends webhook to Python service
5. Python service sends PATCH request to status API

## 🚀 Quick Start

### Step 1: Install Dependencies

```bash
# Install Flask and requests
pip3 install flask requests
```

### Step 2: Start Webhook Service

```bash
cd /home/ella/kevin/telemetry
./start-webhook-service.sh
```

The webhook service will:
- Listen on `http://localhost:5000`
- Accept webhooks at `/webhook/grafana`
- Log all activities to `webhook_service.log`

### Step 3: Restart Grafana

```bash
docker restart kevin-telemetry-grafana
```

Grafana will automatically load the alert rule configuration from:
`grafana/provisioning/alerting/srs-okbps-alert.yml`

### Step 4: Start Test Agent (if not running)

```bash
./start-test-agent.sh tpe
```

## 📁 Files Created

### 1. Webhook Service
- **`grafana_webhook_service.py`** - Python Flask service that receives alerts and triggers API calls
- **`start-webhook-service.sh`** - Script to start the webhook service
- **`stop-webhook-service.sh`** - Script to stop the webhook service

### 2. Grafana Alert Configuration
- **`grafana/provisioning/alerting/srs-okbps-alert.yml`** - Alert rule and contact point configuration

## 🔧 Configuration

### Alert Rule Details

**Alert Name:** `SRS No Data Alert (okbps=0,0,0)`

**LogQL Query:**
```logql
count_over_time({job="srs_test", instance="telemetry-promtail-test-agent"} |= "okbps=0,0,0" [5m])
```

**Trigger Condition:**
- Checks every 30 seconds
- Fires when `okbps=0,0,0` is detected in the last 5 minutes
- Alert stays in pending state for 1 minute before firing
- Repeats notification every 5 minutes while condition persists

### API Call Configuration

When alert fires, the webhook service sends:

```bash
curl -X 'PATCH' \
  'http://localhost:8085/v1/service/status' \
  -H 'accept: application/json' \
  -H 'x-signature: rgs-local-signature' \
  -H 'Content-Type: application/json' \
  -d '{
  "tableId": "ARO-001",
  "zCam": "down"
}'
```

**Parameters:**
- **`tableId`**: Extracted from alert annotations (default: `ARO-001`)
- **`zCam`**: Set to `down` when alert fires

## 🧪 Testing

### Test 1: Health Check

```bash
curl http://localhost:5000/health
```

Expected response:
```json
{
  "status": "healthy",
  "timestamp": "2025-10-01T14:30:00.123456"
}
```

### Test 2: Manual API Trigger

```bash
curl -X POST http://localhost:5000/test \
  -H 'Content-Type: application/json' \
  -d '{"tableId": "ARO-001", "status": "down"}'
```

### Test 3: Simulate Grafana Webhook

```bash
curl -X POST http://localhost:5000/webhook/grafana \
  -H 'Content-Type: application/json' \
  -d '{
  "status": "firing",
  "alerts": [{
    "labels": {"alertname": "SRSNoDataAlert"},
    "annotations": {"table_id": "ARO-001"}
  }]
}'
```

### Test 4: Generate Test Log

Add a test log entry with `okbps=0,0,0`:

```bash
echo "[$(date '+%Y-%m-%d %H:%M:%S')][INFO][test] <- CPB time=1234567890, okbps=0,0,0, ikbps=0,0,0, mr=0/350" >> /home/ella/share_folder/srs.log
```

Wait 1-2 minutes for alert to trigger.

## 📊 Monitoring

### View Webhook Service Logs

```bash
tail -f /home/ella/kevin/telemetry/webhook_service.log
```

### View Grafana Alerts

1. Go to Grafana: `http://100.64.0.160:3000`
2. Navigate to **Alerting → Alert rules**
3. Look for **SRS No Data Alert (okbps=0,0,0)**

### Check Alert Status

```bash
# Check if webhook service is running
ps aux | grep grafana_webhook_service

# View recent webhook activity
tail -n 50 /home/ella/kevin/telemetry/webhook_service.log
```

## 🛠️ Troubleshooting

### Issue: Webhook service not starting

```bash
# Check if Flask is installed
python3 -c "import flask"

# Install if missing
pip3 install flask requests

# Check log file
cat webhook_service.log
```

### Issue: Alert not firing

1. **Check if test agent is running:**
   ```bash
   docker ps | grep test-agent
   ```

2. **Verify logs in Loki:**
   - Go to Grafana Explore
   - Query: `{job="srs_test"} |= "okbps=0,0,0"`

3. **Check alert evaluation:**
   - Grafana → Alerting → Alert rules
   - Click on the alert to see evaluation history

### Issue: API call failing

1. **Verify API endpoint is available:**
   ```bash
   curl http://localhost:8085/v1/service/status
   ```

2. **Check webhook service logs:**
   ```bash
   grep "API request" webhook_service.log
   ```

3. **Update API endpoint if needed:**
   Edit `grafana_webhook_service.py` and change:
   ```python
   API_ENDPOINT = "http://your-actual-endpoint:port/v1/service/status"
   ```

## 🔄 Stopping Services

```bash
# Stop webhook service
./stop-webhook-service.sh

# Stop test agent
./stop-test-agent.sh
```

## 📝 Customization

### Change Table ID

Edit `grafana/provisioning/alerting/srs-okbps-alert.yml`:

```yaml
annotations:
  table_id: 'YOUR-TABLE-ID'  # Change this
```

### Change Alert Threshold

Edit the alert rule to change detection window:

```yaml
expr: 'count_over_time({job="srs_test"} |= "okbps=0,0,0" [10m])'  # Change from 5m to 10m
```

### Add More Alerts

You can add additional alert rules by editing `srs-okbps-alert.yml` or creating new YAML files in the alerting directory.

## 🔐 Security Notes

- The webhook service runs on localhost (port 5000)
- API signature is hardcoded: `rgs-local-signature`
- Consider adding authentication if exposing externally
- Logs may contain sensitive information

## 📚 Related Documentation

- [Grafana Alerting Documentation](https://grafana.com/docs/grafana/latest/alerting/)
- [Loki LogQL Documentation](https://grafana.com/docs/loki/latest/logql/)
- Flask Documentation: https://flask.palletsprojects.com/

