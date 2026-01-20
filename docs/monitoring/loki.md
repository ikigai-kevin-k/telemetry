# Loki Monitoring

## Overview

Loki is a log aggregation system designed to be very cost-effective and easy to operate. It collects logs from Promtail agents.

## Access

- **URL**: http://localhost:3100
- **Container**: `kevin-telemetry-loki-server`

## Log Sources

- SRS logs from agents
- Application logs (mock_sicbo.log, server.log)
- SDP logs

## Query Examples

```logql
# All logs from job
{job="srs_test"}

# Filter by instance
{job="srs_test", instance="telemetry-promtail-test-agent"}

# Search for specific content
{job="srs_test"} |= "okbps=0,0,0"

# Count over time
count_over_time({job="srs_test"} |= "okbps=0,0,0" [5m])
```

## Verify Service

```bash
# Check readiness
curl http://localhost:3100/ready

# Query logs
curl -G -s "http://localhost:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={job="srs_test"}' \
  --data-urlencode 'limit=100'
```

## LogQL Syntax

Loki uses LogQL (Log Query Language) for querying logs:

- **Stream Selectors**: `{job="srs_test", instance="agent1"}`
- **Filter Expressions**: `|= "error"` (contains), `!= "debug"` (not contains)
- **Line Filters**: `| json` (parse JSON), `| regexp` (regex matching)
- **Range Aggregations**: `rate()`, `count_over_time()`, `sum_over_time()`




