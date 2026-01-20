# Services

## Service Overview

| Service | Container Name | Port | Description |
|---------|---------------|------|-------------|
| Prometheus | `kevin-telemetry-prometheus` | 9090 | Metrics collection and storage |
| Grafana | `kevin-telemetry-grafana` | 3000 | Visualization and dashboards |
| Loki | `kevin-telemetry-loki-server` | 3100 | Log aggregation server |
| Alertmanager | `kevin-telemetry-alertmanager` | 9093 | Alert routing and notifications |
| Pushgateway | `kevin-telemetry-pushgateway` | 9091 | Client metrics push endpoint |
| Zabbix Server | `kevin-telemetry-zabbix-server` | 10051 | System monitoring server |
| Zabbix Web | `kevin-telemetry-zabbix-web` | 8080 | Zabbix web interface |
| Zabbix DB | `kevin-telemetry-zabbix-db` | 3306 | MySQL database for Zabbix |
| Webhook Service | `kevin-telemetry-webhook` | 5000 | Grafana alert handler |

## Service Details

### Prometheus
Time-series database for metrics collection and storage. Scrapes metrics from various targets and stores them for querying.

### Grafana
Visualization platform that connects to Prometheus, Loki, and Zabbix to create dashboards and alerts.

### Loki
Log aggregation system designed to be very cost-effective and easy to operate. Collects logs from Promtail agents.

### Zabbix
Enterprise-class open source monitoring solution for networks and applications. Monitors system resources and performance.

### Alertmanager
Handles alerts sent by client applications such as Prometheus. Routes alerts to various notification channels.

### Pushgateway
Allows ephemeral and batch jobs to expose their metrics to Prometheus.

### Webhook Service
Custom Python service that receives Grafana alerts and triggers API calls or other actions.




