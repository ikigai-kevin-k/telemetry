# Kevin Telemetry Stack

This directory contains a Docker setup for Grafana and Prometheus monitoring stack.

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

- Prometheus: `kevin-telemetry-prometheus`
- Grafana: `kevin-telemetry-grafana`

## Container Management

### View Container Sizes

To check the current size and resource usage of the containers:

```bash
# View container status and sizes
docker ps -a --filter "name=kevin-telemetry" --format "table {{.Names}}\t{{.Size}}\t{{.Status}}"

# View real-time resource usage
docker stats --no-stream kevin-telemetry-grafana kevin-telemetry-prometheus

# View detailed disk usage
docker system df -v | grep -A 5 -B 5 "kevin-telemetry"
```

## Configuration

- Prometheus configuration: `prometheus.yml`
- Grafana datasource: `grafana/provisioning/datasources/prometheus.yml`
- Grafana dashboards: `grafana/provisioning/dashboards/`

## Dashboards

### Studio Web Player Dashboard

The `studio-web-player` dashboard includes:
- **Video Stutter Metrics**: Time series chart showing video stutter over time
- **Current Video Stutter Value**: Stat panel displaying current stutter value with color-coded thresholds

**Metrics Available:**
- `videostutter` - Video stutter gauge with labels (player_id, video_id, quality)
- `video_play_total` - Counter for total video plays

## Example Metrics Server

A sample Node.js application that generates `videostutter` metrics:

```bash
# Install dependencies
npm install

# Start the metrics server
npm start

# Or run in development mode
npm run dev
```

The server runs on port 8080 and provides:
- `/metrics` - Prometheus metrics endpoint
- `/health` - Health check endpoint

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
