# Dashboards Configuration

Pre-provisioned dashboards are located in `grafana/provisioning/dashboards/`:

## Available Dashboards

### General
- `overview.json` - Main overview dashboard

### Prometheus
- `studio-web-player.json` - Video stutter metrics
- `prometheus-test.json` - Test metrics

### Loki
- `test-agent-srs.json` - SRS log monitoring

### SDP
- `aro-001-1-sdp-logs.json` - SDP log analysis

### Zabbix
- `master-agents-monitoring.json` - Agent monitoring
- `zabbix-GC-ARO-002-2-system-monitoring.json` - System metrics

### ZCAM
- `zcam-http-response-monitoring.json` - Camera HTTP response monitoring

### BytePlus
- `byteplus-prometheus.json` - BytePlus metrics
- `video-stutter-test.json` - Video stutter testing

### Network
- `network-monitor-enp86s0.json` - Network interface monitoring

## Adding New Dashboards

1. Create dashboard JSON in `grafana/provisioning/dashboards/`
2. Dashboard will be automatically provisioned on Grafana startup
3. Push to trigger GHCR build (if needed)

## Dashboard Organization

Dashboards are organized by folder:
- General dashboards in root
- Service-specific dashboards in subfolders
- Agent-specific dashboards in agent folders




