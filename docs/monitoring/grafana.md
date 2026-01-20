# Grafana Monitoring

## Overview

Grafana is a visualization platform that connects to Prometheus, Loki, and Zabbix to create dashboards and alerts.

## Access

- **URL**: http://localhost:3000
- **Default Credentials**: admin/admin
- **Container**: `kevin-telemetry-grafana`

## Features

- **Dashboards**: Pre-provisioned dashboards for all data sources
- **Alerts**: Configure alert rules and notification channels
- **Explore**: Query Prometheus, Loki, and Zabbix directly
- **Data Sources**: Prometheus, Loki, Zabbix, BytePlus VMP

## Common Tasks

### View Dashboards

1. Navigate to Dashboards
2. Browse available dashboards
3. Select a dashboard to view

### Create Alerts

1. Go to Alerting → Alert Rules
2. Create new alert rule
3. Configure query and conditions
4. Set notification channels

### Query Data

1. Go to Explore
2. Select data source (Prometheus, Loki, or Zabbix)
3. Enter query
4. View results

## Verify Service

```bash
# Check health
curl http://localhost:3000/api/health

# Check data sources
curl -u admin:admin http://localhost:3000/api/datasources
```




