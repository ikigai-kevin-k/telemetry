# Adding New Dashboards

## Overview

Dashboards are automatically provisioned from JSON files in `grafana/provisioning/dashboards/`.

## Steps

### 1. Create Dashboard JSON

Create a new JSON file in the appropriate folder:

```bash
# General dashboard
grafana/provisioning/dashboards/overview.json

# Service-specific dashboard
grafana/provisioning/dashboards/prometheus/video-stutter.json
```

### 2. Dashboard Structure

A basic dashboard JSON structure:

```json
{
  "dashboard": {
    "title": "My Dashboard",
    "panels": [
      {
        "title": "Panel Title",
        "targets": [
          {
            "expr": "up",
            "datasource": "Prometheus"
          }
        ]
      }
    ]
  }
}
```

### 3. Export from Grafana

Alternatively, export an existing dashboard:

1. Open dashboard in Grafana
2. Click Settings → JSON Model
3. Copy JSON content
4. Save to appropriate file

### 4. Auto-provisioning

Dashboards are automatically loaded when Grafana starts:

- On container startup
- On configuration file changes
- On manual reload

### 5. Verify

1. Restart Grafana: `docker compose restart grafana`
2. Check dashboards in Grafana UI
3. Verify panels are working

## Best Practices

- Organize dashboards by folder
- Use descriptive names
- Include documentation in dashboard description
- Test queries before adding to dashboard
- Version control dashboard JSON files




