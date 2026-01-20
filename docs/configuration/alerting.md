# Alerting Configuration

## Alertmanager Configuration

Alerts are configured in `alertmanager-production.yml`:

- **Slack Integration**: Sends alerts to Slack channels
- **Route Configuration**: Routes alerts by severity and labels

## Grafana Alert Rules

Alert rules are defined in `grafana/provisioning/alerting/`:

- **SRS No Data Alert**: Triggers when `okbps=0,0,0` is detected
- Sends webhook to `grafana_webhook_service.py`
- Webhook service makes API calls to status endpoint

## Webhook Service

The webhook service (`grafana_webhook_service.py`) receives Grafana alerts and:

- Logs alert details
- Makes PATCH requests to status API
- Handles health checks

### Start Webhook Service

```bash
./start-webhook-service.sh

# Or manually
python3 grafana_webhook_service.py
```

## Alert Flow

```
Grafana Alert Rule → Webhook Service → API Endpoint
```

## Configuration Files

- `alertmanager-production.yml` - Alertmanager configuration
- `grafana/provisioning/alerting/` - Grafana alert rules
- `grafana_webhook_service.py` - Webhook handler service




