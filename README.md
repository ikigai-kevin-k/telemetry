# Studio Telemetry Stack

A comprehensive monitoring and observability platform built with Grafana, Prometheus, Loki, Zabbix, and related services. This project supports both server-side and agent-side deployments for distributed monitoring across multiple environments.

## 📋 Overview

This telemetry stack provides:
- **Metrics Collection**: Prometheus for time-series metrics
- **Log Aggregation**: Loki for centralized log collection
- **System Monitoring**: Zabbix for infrastructure monitoring
- **Visualization**: Grafana dashboards for all data sources
- **Alerting**: Alertmanager with Slack integration
- **Client Push**: Pushgateway for client-side metrics
- **Webhook Service**: Python service for Grafana alert processing

## 🏗️ Architecture

### Server-Side (Main/Server Branch)
Runs the complete monitoring stack:
- **Prometheus**: Metrics collection and storage (Port 9090)
- **Grafana**: Visualization and dashboards (Port 3000)
- **Loki Server**: Log aggregation server (Port 3100)
- **Zabbix Server/Web/DB**: System monitoring (Port 10051, 8080)
- **Alertmanager**: Alert routing and notifications (Port 9093)
- **Pushgateway**: Client metrics push endpoint (Port 9091)
- **Webhook Service**: Grafana alert handler

### Agent-Side (Agent Branch)
Runs lightweight collectors:
- **Promtail**: Log collection agent (sends to server Loki)
- **Zabbix Agent**: System metrics agent (sends to server Zabbix)

## 🚀 Quick Start

### Server Mode

1. **Start server services:**
   ```bash
   # GE Server (default: 100.64.0.113)
   ./start-server.sh ge
   
   # TPE Server (100.64.0.160)
   ./start-server.sh tpe
   
   # Or use docker compose directly
   SERVER_IP=100.64.0.113 docker compose up -d
   ```

2. **Access services:**
   - Grafana: http://100.64.0.113:3000 (admin/admin)
   - Prometheus: http://100.64.0.113:9090
   - Alertmanager: http://100.64.0.113:9093
   - Loki: http://100.64.0.113:3100
   - Zabbix Web: http://100.64.0.113:8080
   - Pushgateway: http://100.64.0.113:9091

### Agent Mode

1. **Start agent services:**
   ```bash
   # Start agent with name and IP
   ./start-agent.sh GC-aro12-agent 100.64.0.149
   
   # Or start specific agent
   docker compose -f docker-compose-GC-aro12-agent.yml up -d
   ```

2. **Agent connects to server:**
   - Promtail sends logs to server Loki (100.64.0.113:3100)
   - Zabbix Agent sends metrics to server Zabbix (100.64.0.113:10051)

### Using Docker Compose

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

## 📦 Services

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

## 🔧 Configuration

### Data Sources

Grafana is pre-configured with the following data sources:
- **Prometheus**: `http://prometheus:9090`
- **Loki**: `http://loki:3100`
- **Zabbix**: Zabbix API connection
- **BytePlus VMP**: Cloud metrics (requires credentials)

### Dashboards

Pre-provisioned dashboards located in `grafana/provisioning/dashboards/`:

- **General**
  - `overview.json` - Main overview dashboard

- **Prometheus**
  - `studio-web-player.json` - Video stutter metrics
  - `prometheus-test.json` - Test metrics

- **Loki**
  - `test-agent-srs.json` - SRS log monitoring

- **SDP**
  - `aro-001-1-sdp-logs.json` - SDP log analysis

- **Zabbix**
  - `master-agents-monitoring.json` - Agent monitoring
  - `zabbix-GC-ARO-002-2-system-monitoring.json` - System metrics

- **ZCAM**
  - `zcam-http-response-monitoring.json` - Camera HTTP response monitoring

- **BytePlus**
  - `byteplus-prometheus.json` - BytePlus metrics
  - `video-stutter-test.json` - Video stutter testing

- **Network**
  - `network-monitor-enp86s0.json` - Network interface monitoring

### Environment Variables

Create `byteplus-credentials.env` for BytePlus VMP access:
```bash
BYTEPLUS_ACCESS_KEY=your_access_key
BYTEPLUS_SECRET_KEY=your_secret_key
```

For Slack alerts, set:
```bash
export SLACK_WEBHOOK_URL=https://hooks.slack.com/services/your/webhook/url
```

## 📊 Data Sources

### Prometheus Metrics

**Available Metrics:**
- `videostutter{table_id, cdn_id, quality}` - Video stutter gauge
- `video_play_total` - Video play counter
- `http_response_*` - HTTP response metrics from Telegraf
- `zabbix_*` - System metrics from Zabbix

**Push Metrics via Pushgateway:**
```bash
curl -X POST -d "videostutter{table_id=\"ARO-001\",cdn_id=\"byteplus\",quality=\"HD\"} 5" \
  http://localhost:9091/metrics/job/studio-web-player
```

### Loki Logs

**Log Sources:**
- SRS logs from agents
- Application logs (mock_sicbo.log, server.log)
- SDP logs

**Query Examples:**
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

### Zabbix Metrics

Zabbix collects system metrics from agents:
- CPU, Memory, Disk usage
- Network interface statistics
- System load and processes

## 🔔 Alerting

### Alertmanager Configuration

Alerts are configured in `alertmanager-production.yml`:
- **Slack Integration**: Sends alerts to Slack channels
- **Route Configuration**: Routes alerts by severity and labels

### Grafana Alert Rules

Alert rules are defined in `grafana/provisioning/alerting/`:
- **SRS No Data Alert**: Triggers when `okbps=0,0,0` is detected
- Sends webhook to `grafana_webhook_service.py`
- Webhook service makes API calls to status endpoint

### Webhook Service

The webhook service (`grafana_webhook_service.py`) receives Grafana alerts and:
- Logs alert details
- Makes PATCH requests to status API
- Handles health checks

**Start webhook service:**
```bash
./start-webhook-service.sh

# Or manually
python3 grafana_webhook_service.py
```

## 🐳 Docker Images & CI/CD

### GitHub Actions Workflow

Automated Docker image builds via `.github/workflows/build-and-push.yml`:

**Trigger Conditions:**
- Push to `main`, `server`, or `agent` branches
- Changes to:
  - `Dockerfile.webhook`
  - `grafana_webhook_service.py`
  - `.github/workflows/build-and-push.yml`
  - `grafana/provisioning/dashboards/**/*.json`
  - `grafana/provisioning/datasources/**/*.yml`
  - `grafana/provisioning/alerting/**/*.yml`

**Image Naming:**
- `server` branch → `ghcr.io/ikigai-kevin-k/telemetry-server`
- `agent` branch → `ghcr.io/ikigai-kevin-k/telemetry-agent`
- `main` branch → `ghcr.io/ikigai-kevin-k/telemetry-webhook`

**Manual Trigger:**
- Go to Actions → "Build and Push to GHCR" → "Run workflow"
- Select branch and optional custom tag

### Image Tags

Each build creates multiple tags:
- Branch suffix (e.g., `server`, `agent`, `webhook`)
- SHA-based tag (e.g., `server-{sha}`)
- Run number tag (e.g., `server-{run_number}`)

## 📁 Project Structure

```
telemetry/
├── .github/
│   └── workflows/
│       └── build-and-push.yml      # CI/CD workflow
├── grafana/
│   └── provisioning/
│       ├── dashboards/             # Grafana dashboards
│       ├── datasources/            # Data source configs
│       └── alerting/               # Alert rules
├── zabbix/                         # Zabbix agent configs
├── telegraf/                       # Telegraf configs
├── agent-configs/                   # Agent configurations
├── docker-compose.yml              # Server services
├── docker-compose-*.yml            # Agent-specific configs
├── Dockerfile.webhook              # Webhook service image
├── grafana_webhook_service.py      # Webhook service
├── prometheus.yml                   # Prometheus config
├── loki-config.yml                 # Loki config
├── promtail-config.yml             # Promtail config
├── start-server.sh                 # Server startup script
├── start-agent.sh                  # Agent startup script
└── README.md                       # This file
```

## 🔍 Monitoring & Troubleshooting

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

### Check Data Persistence

```bash
# Prometheus data
docker volume inspect telemetry_prometheus_data

# Grafana data
docker volume inspect telemetry_grafana_data

# Loki data
docker volume inspect telemetry_loki_data
```

### Verify Services

```bash
# Prometheus targets
curl http://localhost:9090/api/v1/targets

# Loki ready
curl http://localhost:3100/ready

# Grafana health
curl http://localhost:3000/api/health

# Pushgateway metrics
curl http://localhost:9091/metrics
```

## 📚 Documentation

Additional documentation:
- `AGENT_MANAGEMENT.md` - Agent setup and management
- `LOGGING_SETUP.md` - Loki logging configuration
- `GRAFANA_ALERT_WEBHOOK_SETUP.md` - Alert webhook setup
- `ZCAM_Telegraf_Grafana_Setup.md` - ZCAM monitoring setup
- `LOKI_ARCHITECTURE.md` - Loki architecture overview

## 🛠️ Development

### Adding New Dashboards

1. Create dashboard JSON in `grafana/provisioning/dashboards/`
2. Dashboard will be automatically provisioned on Grafana startup
3. Push to trigger GHCR build (if needed)

### Adding New Data Sources

1. Add datasource config to `grafana/provisioning/datasources/`
2. Restart Grafana or wait for auto-reload

### Testing Changes

1. Make changes to configuration files
2. Restart affected services: `docker compose restart <service>`
3. Verify in Grafana UI

## 🔐 Security Notes

- Default Grafana credentials: `admin/admin` (change in production)
- BytePlus credentials stored in `.env` file (not committed)
- Network isolation via Docker bridge network
- Zabbix database uses default passwords (change in production)



## 👥 Contributors

Studio Team - ikigai-kevin-k

---

**Last Updated**: 2025-11-06
