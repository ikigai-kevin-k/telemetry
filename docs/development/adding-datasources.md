# Adding New Data Sources

## Overview

Data sources are automatically provisioned from YAML files in `grafana/provisioning/datasources/`.

## Steps

### 1. Create Datasource YAML

Create a new YAML file:

```yaml
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
    jsonData:
      httpMethod: POST
```

### 2. Datasource Types

Common datasource types:

- **Prometheus**: `type: prometheus`
- **Loki**: `type: loki`
- **Zabbix**: `type: alexanderzobnin-zabbix-datasource`
- **MySQL**: `type: mysql`
- **PostgreSQL**: `type: postgres`

### 3. Configuration Options

```yaml
datasources:
  - name: My Datasource
    type: prometheus
    access: proxy  # or direct
    url: http://service:port
    isDefault: false
    editable: true
    jsonData:
      httpMethod: POST
      timeInterval: 15s
    secureJsonData:
      password: secret
```

### 4. Auto-provisioning

Data sources are automatically loaded when Grafana starts:

- On container startup
- On configuration file changes
- On manual reload

### 5. Verify

1. Restart Grafana: `docker compose restart grafana`
2. Check data sources in Grafana UI
3. Test connection

## Best Practices

- Use service names in Docker network
- Set appropriate timeouts
- Configure authentication securely
- Test connections before deploying
- Document datasource purpose




