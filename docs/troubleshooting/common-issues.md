# Common Issues

## Container Issues

### Containers Not Starting

```bash
# Check container status
docker compose ps

# View logs
docker compose logs

# Check for port conflicts
netstat -tulpn | grep -E '3000|9090|3100'
```

### Container Restarting

```bash
# Check logs for errors
docker compose logs <service-name>

# Check resource usage
docker stats

# Check disk space
df -h
```

## Service Connection Issues

### Cannot Connect to Services

1. Verify containers are running: `docker compose ps`
2. Check firewall rules
3. Verify network configuration
4. Check service logs for errors

### Data Source Connection Failed

1. Verify service is running
2. Check service URL in Grafana
3. Verify network connectivity
4. Check service logs

## Data Issues

### No Data in Dashboards

1. Verify data sources are configured
2. Check if services are collecting data
3. Verify time range in dashboard
4. Check query syntax

### Missing Metrics

1. Verify targets are being scraped (Prometheus)
2. Check agent configuration (Zabbix)
3. Verify log collection (Loki)
4. Check service logs

## Performance Issues

### High Resource Usage

```bash
# Check container resource usage
docker stats

# Check system resources
top
htop

# Check disk I/O
iostat -x 1
```

### Slow Queries

1. Optimize query syntax
2. Reduce time range
3. Add query limits
4. Check data retention settings




