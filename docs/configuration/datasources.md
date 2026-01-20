# Data Sources Configuration

Grafana is pre-configured with the following data sources:

## Pre-configured Data Sources

- **Prometheus**: `http://prometheus:9090`
- **Loki**: `http://loki:3100`
- **Zabbix**: Zabbix API connection
- **BytePlus VMP**: Cloud metrics (requires credentials)

## Adding New Data Sources

1. Add datasource config to `grafana/provisioning/datasources/`
2. Restart Grafana or wait for auto-reload

Example datasource configuration:

```yaml
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
```

## BytePlus VMP Configuration

Create `byteplus-credentials.env` for BytePlus VMP access:

```bash
BYTEPLUS_ACCESS_KEY=your_access_key
BYTEPLUS_SECRET_KEY=your_secret_key
```

## Verifying Data Sources

Access Grafana at http://localhost:3000 and navigate to:
- Configuration → Data Sources
- Test each data source connection




