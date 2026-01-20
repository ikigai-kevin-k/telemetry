# Architecture

The Studio Telemetry Stack follows a distributed architecture pattern with clear separation between server-side and agent-side components.

## Server-Side (Main/Server Branch)

Runs the complete monitoring stack:

- **Prometheus**: Metrics collection and storage (Port 9090)
- **Grafana**: Visualization and dashboards (Port 3000)
- **Loki Server**: Log aggregation server (Port 3100)
- **Zabbix Server/Web/DB**: System monitoring (Port 10051, 8080)
- **Alertmanager**: Alert routing and notifications (Port 9093)
- **Pushgateway**: Client metrics push endpoint (Port 9091)
- **Webhook Service**: Grafana alert handler

## Agent-Side (Agent Branch)

Runs lightweight collectors:

- **Promtail**: Log collection agent (sends to server Loki)
- **Zabbix Agent**: System metrics agent (sends to server Zabbix)

## Data Flow

```
┌─────────────────────────────────┐    ┌─────────────────────────────────┐
│        Server 端                │    │        Agent 端                 │
│    100.64.0.160                │    │    100.64.0.149                │
│                                │    │                                │
│  ┌─────────────────────────┐   │    │  ┌─────────────────────────┐   │
│  │    Loki Server          │◀──┼────┼──│    Promtail Agent       │   │
│  │    Port 3100            │   │    │  │    (Log Collector)      │   │
│  └─────────────────────────┘   │    │  └─────────────────────────┘   │
│                                │    │                                │
│  ┌─────────────────────────┐   │    │  ┌─────────────────────────┐   │
│  │    Zabbix Server        │◀──┼────┼──│    Zabbix Agent         │   │
│  │    Port 10051           │   │    │  │    (Metrics Collector)  │   │
│  └─────────────────────────┘   │    │  └─────────────────────────┘   │
│                                │    │                                │
│  ┌─────────────────────────┐   │    │                                │
│  │    Prometheus           │   │    │                                │
│  │    Port 9090            │   │    │                                │
│  └─────────────────────────┘   │    │                                │
│                                │    │                                │
│  ┌─────────────────────────┐   │    │                                │
│  │    Grafana              │   │    │                                │
│  │    Port 3000            │   │    │                                │
│  └─────────────────────────┘   │    │                                │
└─────────────────────────────────┘    └─────────────────────────────────┘
```

## Network Architecture

- Agents connect to the server via Tailscale network
- All services communicate through Docker bridge network
- External access via exposed ports

## Deployment Models

### Single Server Deployment
All services run on a single server. Suitable for small to medium deployments.

### Distributed Deployment
Server-side services run on dedicated monitoring server, agents run on monitored hosts. Suitable for large-scale deployments.




