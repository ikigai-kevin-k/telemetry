# Data Persistence

## Volume Management

### Check Volumes

```bash
# List all volumes
docker volume ls | grep telemetry

# Inspect specific volume
docker volume inspect telemetry_prometheus_data
docker volume inspect telemetry_grafana_data
docker volume inspect telemetry_loki_data
```

### Backup Volumes

```bash
# Backup Prometheus data
docker run --rm -v telemetry_prometheus_data:/data -v $(pwd):/backup \
  alpine tar czf /backup/prometheus-backup.tar.gz -C /data .

# Backup Grafana data
docker run --rm -v telemetry_grafana_data:/data -v $(pwd):/backup \
  alpine tar czf /backup/grafana-backup.tar.gz -C /data .

# Backup Loki data
docker run --rm -v telemetry_loki_data:/data -v $(pwd):/backup \
  alpine tar czf /backup/loki-backup.tar.gz -C /data .
```

### Restore Volumes

```bash
# Restore Prometheus data
docker run --rm -v telemetry_prometheus_data:/data -v $(pwd):/backup \
  alpine tar xzf /backup/prometheus-backup.tar.gz -C /data

# Restore Grafana data
docker run --rm -v telemetry_grafana_data:/data -v $(pwd):/backup \
  alpine tar xzf /backup/grafana-backup.tar.gz -C /data

# Restore Loki data
docker run --rm -v telemetry_loki_data:/data -v $(pwd):/backup \
  alpine tar xzf /backup/loki-backup.tar.gz -C /data
```

## Data Retention

### Prometheus Retention

Configure in `prometheus.yml`:

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    monitor: 'telemetry'

# Storage retention
storage:
  tsdb:
    retention.time: 30d
    retention.size: 50GB
```

### Loki Retention

Configure in `loki-config.yml`:

```yaml
limits_config:
  retention_period: 720h  # 30 days
```

## Disk Space Management

### Check Disk Usage

```bash
# Check volume sizes
docker system df -v

# Check specific volume
du -sh /var/lib/docker/volumes/telemetry_*/
```

### Clean Up Old Data

```bash
# Clean Prometheus old data
docker exec kevin-telemetry-prometheus promtool tsdb clean \
  --storage.tsdb.path=/prometheus

# Clean Docker system
docker system prune -a --volumes
```




