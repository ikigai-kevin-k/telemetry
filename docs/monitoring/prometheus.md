# Prometheus Monitoring

## Overview

Prometheus is a time-series database for metrics collection and storage. It scrapes metrics from various targets and stores them for querying.

## Access

- **URL**: http://localhost:9090
- **Container**: `kevin-telemetry-prometheus`

## Available Metrics

- `videostutter{table_id, cdn_id, quality}` - Video stutter gauge
- `video_play_total` - Video play counter
- `http_response_*` - HTTP response metrics from Telegraf
- `zabbix_*` - System metrics from Zabbix

## Push Metrics via Pushgateway

```bash
curl -X POST -d "videostutter{table_id=\"ARO-001\",cdn_id=\"byteplus\",quality=\"HD\"} 5" \
  http://localhost:9091/metrics/job/studio-web-player
```

## Query Examples

```promql
# Query video stutter
videostutter

# Query with labels
videostutter{table_id="ARO-001"}

# Rate calculation
rate(video_play_total[5m])
```

## Verify Service

```bash
# Check targets
curl http://localhost:9090/api/v1/targets

# Check metrics
curl http://localhost:9090/api/v1/label/__name__/values
```




