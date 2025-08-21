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
- `videostutter` - Video stutter gauge with labels (table_id, cdn_id, quality)
  - **table_id**: ARO-001, ARO-002, SBO-001, BCR-001
  - **cdn_id**: byteplus, tencent, cdnnetwork
  - **quality**: HD, Hi, Me, Lo
- `video_play_total` - Counter for total video plays

**Important Setup Note:**
After the dashboard is first loaded, you need to manually execute the query to see data:
1. Click on any panel to enter edit mode
2. In the query editor, ensure the query is: `videostutter{job="studio-web-player"}`
3. Click "Run queries" to execute the query
4. The dashboard will then display the metrics data

**Dashboard Features:**
- **Time Range**: Default set to "Last 15 minutes" for recent data
- **Auto Refresh**: Every 30 seconds (matches metrics sampling rate)
- **Legend Format**: `{{table_id}} - {{cdn_id}} - {{quality}}`
- **Color Coding**: Values are color-coded based on thresholds (Green: 0-4, Yellow: 5-9, Red: 10+)

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

### Stopping the Background Server

To stop the background running metrics server:

```bash
# Method 1: Find and kill by process ID
ps aux | grep "example-metrics-server" | grep -v grep
kill <PID>

# Method 2: Kill by process name
pkill -f "example-metrics-server"

# Method 3: Kill all Node.js processes (use with caution)
killall node

# Method 4: Force kill if normal kill doesn't work
kill -9 <PID>
```

**Note:** After stopping the server, Prometheus targets will show as "down" since it can't connect to the metrics endpoint.

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

### Dashboard Shows "No Data"

If your dashboard displays "No data" even though metrics exist in Prometheus:

1. **Check Query Execution**: 
   - Enter edit mode for any panel
   - Ensure the query is correct: `videostutter{job="studio-web-player"}`
   - Click "Run queries" to execute

2. **Verify Time Range**:
   - Check if time range is set to "Last 15 minutes" or appropriate range
   - Ensure data exists within the selected time window

3. **Check Data Source**:
   - Verify Prometheus data source is connected
   - Check if metrics are being scraped successfully

4. **Common Solutions**:
   - Restart Grafana: `docker compose restart grafana`
   - Check Prometheus targets status
   - Verify metrics server is running and generating data
