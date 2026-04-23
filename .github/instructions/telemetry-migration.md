---
applyTo: "**/*"
---

# Telemetry Migration Guide (Fresh Start, No History Retention)

This guide describes how to migrate `telemetry` services to a new host when
the goal is:

- all services run correctly on the new machine
- no need to preserve historical state, logs, or metrics

## 1) Migration Scope

Migrate only runtime definitions and operational configuration.
Do not migrate old runtime data volumes.

## 2) What You Must Migrate

### A. Repository and Core Runtime Files

Copy the repository (or clone it) including:

- `docker-compose.yml`
- `docker-compose.agent.yml` (if the new host will run agent-side services)
- `docker-compose-telegraf.yml` (if needed)
- `docker-compose-zcam-exporter.yml` (if needed)
- `Dockerfile.webhook`
- `prometheus.yml`
- `loki-config.yml`
- `promtail-config.yml` and any host-specific promtail config variants
- `alertmanager-production.yml`
- `zcam-temperature-alerts.yml`
- `grafana/` provisioning directory
- `zabbix/` configs and initialization files
- `scripts/` used by services (exporters, helpers)
- start/stop scripts (`start-server.sh`, `start-agent.sh`, etc.)

### B. Secret and Environment Inputs

Prepare these on the new host before startup:

- `.env` values required by compose services
- `byteplus-credentials.env` (if Grafana/BytePlus integration is used)
- `SLACK_WEBHOOK_URL`
- `BYTEPLUS_ACCESS_KEY`
- `BYTEPLUS_SECRET_KEY`
- any site-specific IP or hostname overrides (for example `SERVER_IP`)

Do not commit secrets to git. Inject via env files or host environment.

### C. Host Runtime Prerequisites

Install and verify:

- Docker Engine + Compose plugin (or compatible `docker-compose`)
- network access to upstream/downstream endpoints
- firewall rules for required ports (for example 3000, 3100, 9090, 9093,
  8080, 10051, 10050, 9273, 9274, 9300)
- DNS/host routing needed by metrics and log targets

### D. Optional External Integrations

If used in your deployment, also migrate/verify:

- Slack webhook routing destination
- external metrics targets referenced by `prometheus.yml`
- agent host log file paths referenced by `promtail-config.yml`
- Zabbix endpoint connectivity between server and agents

## 3) What You Do NOT Need to Migrate

Because this is a fresh-start migration, do not move historical Docker data:

- old Docker volumes (for example `telemetry_zabbix_db_data`,
  `telemetry_grafana_data`, `telemetry_prometheus_data`, `telemetry_loki_data`)
- container writable layers
- old container logs
- old local caches/build artifacts

## 4) Recommended Migration Steps

1. Provision new host with Docker and required network access.
2. Copy/clone repository to new host.
3. Populate required environment files and secrets.
4. Validate and update host-specific addresses in configs.
5. Start core stack:
   - server-side: `docker compose up -d`
   - optional stacks:
     - `docker compose -f docker-compose-telegraf.yml up -d`
     - `docker compose -f docker-compose-zcam-exporter.yml up -d`
   - agent-side (if needed):
     - `docker compose -f docker-compose.agent.yml up -d`
6. Verify service health and connectivity.

## 5) Post-Migration Verification Checklist

- Containers are running: `docker ps`
- Loki ready endpoint responds: `http://<host>:3100/ready`
- Prometheus UI is reachable: `http://<host>:9090`
- Alertmanager UI is reachable: `http://<host>:9093`
- Grafana UI is reachable and dashboards load: `http://<host>:3000`
- Zabbix Web is reachable: `http://<host>:8080`
- Prometheus targets are healthy in `/targets`
- Grafana can query both Prometheus and Loki datasources
- Agent logs successfully arrive in Loki (if agents are enabled)

## 6) Rollback Strategy

If startup fails on the new host:

1. Stop services: `docker compose down`
2. Re-check env/secrets and config paths
3. Fix connectivity/firewall issues
4. Restart stack and re-run verification

Because no historical data is required, rollback does not require volume restore.
