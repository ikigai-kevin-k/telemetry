# Server Setup

## Quick Start

### Step 1: Start Server Services

```bash
# GE Server (default: 100.64.0.113)
./start-server.sh ge

# TPE Server (100.64.0.160)
./start-server.sh tpe

# Or use docker compose directly
SERVER_IP=100.64.0.113 docker compose up -d
```

### Step 2: Access Services

Once services are running, you can access:

- **Grafana**: http://100.64.0.113:3000 (admin/admin)
- **Prometheus**: http://100.64.0.113:9090
- **Alertmanager**: http://100.64.0.113:9093
- **Loki**: http://100.64.0.113:3100
- **Zabbix Web**: http://100.64.0.113:8080
- **Pushgateway**: http://100.64.0.113:9091

### Step 3: Verify Services

```bash
# Check container status
docker compose ps

# View logs
docker compose logs -f

# Check specific service
docker compose logs -f grafana
```

## Using Docker Compose

```bash
# Start all services
docker compose up -d

# View logs
docker compose logs -f

# Stop services
docker compose down

# Stop and remove volumes
docker compose down -v
```

## Next Steps

- Configure [Data Sources](../configuration/datasources.md)
- Set up [Dashboards](../configuration/dashboards.md)
- Configure [Alerting](../configuration/alerting.md)
