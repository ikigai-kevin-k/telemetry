# Docker Compose Guide

## Basic Commands

```bash
# Start all services
docker compose up -d

# View logs
docker compose logs -f

# Stop services
docker compose down

# Stop and remove volumes
docker compose down -v

# Restart a specific service
docker compose restart grafana
```

## Service Management

### View Container Status

```bash
# All containers
docker ps -a --filter "name=kevin-telemetry"

# Server services
docker compose ps

# Agent services
docker compose -f docker-compose-GC-aro12-agent.yml ps
```

### View Logs

```bash
# Server logs
docker compose logs -f

# Specific service
docker compose logs -f grafana

# Agent logs
docker compose -f docker-compose-GC-aro12-agent.yml logs -f
```

## Data Persistence

### Check Volumes

```bash
# Prometheus data
docker volume inspect telemetry_prometheus_data

# Grafana data
docker volume inspect telemetry_grafana_data

# Loki data
docker volume inspect telemetry_loki_data
```

### Backup Volumes

```bash
# Backup Prometheus data
docker run --rm -v telemetry_prometheus_data:/data -v $(pwd):/backup \
  alpine tar czf /backup/prometheus-backup.tar.gz -C /data .

# Restore Prometheus data
docker run --rm -v telemetry_prometheus_data:/data -v $(pwd):/backup \
  alpine tar xzf /backup/prometheus-backup.tar.gz -C /data
```

## Environment Variables

Set environment variables in `.env` file or export them:

```bash
# Server IP
export SERVER_IP=100.64.0.113

# Slack webhook
export SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...

# BytePlus credentials
export BYTEPLUS_ACCESS_KEY=your_key
export BYTEPLUS_SECRET_KEY=your_secret
```




