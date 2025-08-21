# Kevin Grafana + Prometheus Stack

This directory contains a Docker Compose setup for Grafana and Prometheus monitoring stack.

## Services

- **Prometheus**: Metrics collection and storage (Port: 9090)
- **Grafana**: Data visualization and dashboards (Port: 3000)

## Quick Start

1. **Start the services:**
   ```bash
   docker compose up -d
   ```

2. **Access the services:**
   - Prometheus: http://localhost:9090
   - Grafana: http://localhost:3000
     - Username: `admin`
     - Password: `admin`

3. **Stop the services:**
   ```bash
   docker compose down
   ```

4. **Stop and remove volumes:**
   ```bash
   docker compose down -v
   ```

## Container Names

- Prometheus: `kevin-grafana-prom-prometheus`
- Grafana: `kevin-grafana-prom-grafana`

## Configuration

- Prometheus configuration: `prometheus.yml`
- Grafana datasource: `grafana/provisioning/datasources/prometheus.yml`

## Data Persistence

- Prometheus data: `prometheus_data` volume
- Grafana data: `grafana_data` volume

## Network

All services are connected through a custom `monitoring` network for isolation.

## Troubleshooting

### Docker Compose Version Issues

If you encounter connection errors like `Not supported URL scheme http+docker`:

1. **Check Docker Compose version:**
   ```bash
   docker compose version
   ```

2. **Use the newer Docker Compose (recommended):**
   ```bash
   docker compose up -d
   ```

3. **Avoid using old docker-compose (1.29.2) which has known connection issues**

### Port Conflicts

- Prometheus runs on port 9090
- Grafana runs on port 3000
- If ports are in use, modify the port mappings in `docker-compose.yml`
