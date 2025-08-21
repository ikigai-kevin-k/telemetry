# Kevin Telemetry Stack

This directory contains a Docker setup for Grafana and Prometheus monitoring stack.

## Services

- **Prometheus**: Metrics collection and storage (Port: 9090)
- **Pushgateway**: Metrics push endpoint for client applications (Port: 9091)
- **Grafana**: Data visualization and dashboards (Port: 3000)

## Quick Start

1. **Start the services:**
   ```bash
   docker compose up -d
   ```

2. **Access the services:**
   - Prometheus: http://localhost:9090
   - Pushgateway: http://localhost:9091
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
- Pushgateway: `kevin-telemetry-pushgateway`
- Grafana: `kevin-telemetry-grafana`

## Container Management

### View Container Sizes

To check the current size and resource usage of the containers:

```bash
# View container status and sizes
docker ps -a --filter "name=kevin-telemetry" --format "table {{.Names}}\t{{.Size}}\t{{.Status}}"

# View real-time resource usage
docker stats --no-stream kevin-telemetry-grafana kevin-telemetry-prometheus kevin-telemetry-pushgateway

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

## Client-Side Metrics (Pure Client)

### Using Pushgateway

For pure client applications that cannot expose a `/metrics` endpoint, you can use **Pushgateway** to send metrics directly:

**Advantages:**
- ✅ No need to expose ports
- ✅ Works from any client (browser, mobile app, etc.)
- ✅ Simple HTTP POST requests
- ✅ Supports batch metrics

**Disadvantages:**
- ⚠️ Single point of failure
- ⚠️ Data may not be real-time
- ⚠️ Additional service to maintain

### Setup and Usage Steps

#### 1. Start Services with Pushgateway
```bash
# Start all services including Pushgateway
docker compose up -d

# Verify all services are running
docker compose ps
```

#### 2. Send Metrics to Pushgateway
```bash
# Single metric format
curl -X POST -d "videostutter{table_id=\"ARO-001\",cdn_id=\"byteplus\",quality=\"HD\"} 5" \
  http://localhost:9091/metrics/job/studio-web-player

# Verify metric received by Pushgateway
curl -s http://localhost:9091/metrics | grep videostutter
```

#### 3. Metric Format Requirements
**Important**: Pushgateway requires specific metric format:
- **Correct Format**: `metric_name{label="value"} metric_value\n`
- **Required Elements**:
  - Metric name (e.g., `videostutter`)
  - Labels in curly braces (e.g., `{table_id="ARO-001",cdn_id="byteplus",quality="HD"}`)
  - Space separator
  - Numeric value (e.g., `5`)
  - **Newline character** (`\n`) at the end

- **Example**: `videostutter{table_id="ARO-001",cdn_id="byteplus",quality="HD"} 5\n`

**Common Format Errors**:
- ❌ Missing newline at end: `videostutter{...} 5`
- ❌ Extra spaces: `videostutter { ... } 5`
- ❌ Invalid label characters: `videostutter{table-id="value"} 5`
- ✅ Correct: `videostutter{table_id="value"} 5\n`

#### 3. Check Prometheus Integration
```bash
# Verify Pushgateway target is healthy
curl -s http://localhost:9090/api/v1/targets | grep -A 10 -B 5 "pushgateway"

# Query metrics in Prometheus
curl -s "http://localhost:9090/api/v1/query?query=videostutter" | grep -o '"value":\[[^]]*\]'
```

#### 4. View in Grafana Dashboard
- Open Grafana: http://localhost:3000 (admin/admin)
- Navigate to "Studio Web Player Dashboard"
- Metrics from Pushgateway will appear automatically

### Client Examples

#### 1. JavaScript Client (`client-example.js`)
```javascript
const client = new PrometheusClient('http://localhost:9091');

// Send single metric
await client.sendVideoStutter('ARO-001', 'byteplus', 'HD', 5);

// Send batch metrics
await client.sendBatchMetrics([
  { name: 'videostutter', value: 8, labels: { table_id: 'ARO-001', cdn_id: 'byteplus', quality: 'HD' } },
  { name: 'videostutter', value: 15, labels: { table_id: 'ARO-002', cdn_id: 'tencent', quality: 'Lo' } }
]);
```

#### 2. Browser Client (`client-example.html`)
- Interactive web interface for testing
- Send single or random metrics
- Real-time logging and status updates

#### 3. Network Accessible Client (`share-client.html`)
- **Network Accessible**: Can be accessed from other computers on the network
- **Pre-configured**: Default Pushgateway URL set to `http://192.168.20.9:9091`
- **Connection Test**: Built-in connection testing functionality
- **Network Info**: Displays network configuration information

#### 3. Usage in Different Environments
```javascript
// Browser
const client = new PrometheusClient('http://your-pushgateway:9091');

// Node.js
const PrometheusClient = require('./client-example.js');
const client = new PrometheusClient('http://localhost:9091');

// Mobile App (React Native, etc.)
// Use the same PrometheusClient class
```

### Testing Pushgateway

#### Test Script
Use the provided test script to verify Pushgateway functionality:
```bash
# Install dependencies
npm install node-fetch

# Run test script
node test-pushgateway.js
```

#### Manual Testing
```bash
# Test single metric
curl -X POST -d "videostutter{table_id=\"ARO-001\",cdn_id=\"byteplus\",quality=\"HD\"} 5" \
  http://localhost:9091/metrics/job/studio-web-player

# Test multiple metrics
curl -X POST -d "videostutter{table_id=\"ARO-002\",cdn_id=\"tencent\",quality=\"Hi\"} 12" \
  http://localhost:9091/metrics/job/studio-web-player
```

### Network Access from Other Computers

#### HTTP Server for Network Sharing
A simple HTTP server is provided to share the client interface across the network:

```bash
# Start the HTTP server in foreground (recommended for development)
node simple-server.js

# Server will be available at:
# - Local: http://localhost:8080
# - Network: http://192.168.20.9:8080

# To stop the server: Press Ctrl+C

# To run in background (for production):
nohup node simple-server.js > server.log 2>&1 &
```

#### Access from Other Computers
1. **From any computer on the same network:**
   - Open browser and navigate to: `http://192.168.20.9:8080`
   - Use the pre-configured Pushgateway URL: `http://192.168.20.9:9091`
   - Send metrics directly from the browser

2. **Network Configuration:**
   - **Server IP**: 192.168.20.9
   - **HTTP Server Port**: 8080
   - **Pushgateway Port**: 9091
   - **Prometheus Port**: 9090
   - **Grafana Port**: 3000

3. **Available Pages:**
   - **Main Page**: `http://192.168.20.9:8080/` (share-client.html)
   - **Client Example**: `http://192.168.20.9:8080/client-example.html`
   - **Network Client**: `http://192.168.20.9:8080/share-client.html`

### Alternative Approaches

#### 1. Direct Metrics Endpoint
If your client can expose a port:
```javascript
// Implement /metrics endpoint in your client
app.get('/metrics', (req, res) => {
  res.set('Content-Type', 'text/plain');
  res.end(formatPrometheusMetrics());
});
```

#### 2. Remote Write API
Direct write to Prometheus (advanced):
```javascript
// Requires Prometheus remote write configuration
const response = await fetch('http://prometheus:9090/api/v1/write', {
  method: 'POST',
  body: prometheusData
});
```

## Example Metrics Server (Node.js)

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

### Prometheus Time Series Database

**Location:**
- **Host path**: `/var/lib/docker/volumes/telemetry_prometheus_data/_data`
- **Container path**: `/prometheus`

**Check Database Size:**
```bash
# Check total database size
docker exec kevin-telemetry-prometheus du -sh /prometheus

# Check detailed directory sizes
docker exec kevin-telemetry-prometheus sh -c "du -sh /prometheus/*"

# Check Docker volume information
docker volume inspect telemetry_prometheus_data

# Check system disk usage for Docker volumes
df -h /var/lib/docker
```

**Database Structure:**
- **TSDB blocks**: Historical time series data
- **chunks_head**: In-memory chunks
- **wal**: Write-ahead log for data durability
- **queries.active**: Active query tracking
- **lock**: Database lock file

**Data Retention:**
- **Retention time**: 200 hours (8.33 days)
- **Configuration**: Set in `docker-compose.yml` with `--storage.tsdb.retention.time=200h`
- **Storage growth**: Database size will increase over time as metrics accumulate
- **Cleanup**: Old data is automatically removed after retention period expires

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

### CORS Issues and Solutions

#### Problem Description
When accessing the client interface from a different computer on the network, you may encounter **CORS (Cross-Origin Resource Sharing)** errors:
- **Error**: `Failed to fetch` or `CORS policy blocked`
- **Cause**: Browsers block direct POST requests to different domains/ports for security reasons
- **Impact**: Metrics cannot be sent directly from browser to Pushgateway

#### Solution: Proxy Endpoint
The system includes a built-in proxy solution to handle CORS issues:

1. **Automatic Fallback**: Client first tries direct connection, then falls back to proxy
2. **Proxy Endpoint**: `/proxy-pushgateway` handles browser requests and forwards them to Pushgateway
3. **CORS Headers**: All responses include proper CORS headers for cross-origin access

#### Technical Implementation
```javascript
// Client-side fallback logic
try {
    // First attempt: Direct connection
    const response = await fetch(pushgatewayUrl, { method: 'POST', body: metricData });
} catch (error) {
    // Fallback: Use proxy endpoint
    const response = await fetch('/proxy-pushgateway', { 
        method: 'POST', 
        body: JSON.stringify({ pushgatewayUrl, jobName, metricData }) 
    });
}
```

#### Proxy Server Features
- **CORS Support**: Handles preflight OPTIONS requests
- **Request Forwarding**: Forwards metrics to Pushgateway with proper formatting
- **Error Handling**: Detailed logging for debugging
- **Security**: Prevents directory traversal attacks

#### Troubleshooting CORS Issues
1. **Check Browser Console**: Look for CORS error messages
2. **Verify Proxy Endpoint**: Ensure `/proxy-pushgateway` is accessible
3. **Check Server Logs**: Look for proxy forwarding messages
4. **Test Direct Connection**: Verify Pushgateway is reachable from server

#### Complete Troubleshooting Flow
```
Browser Error → Check Console → Identify Issue Type
     ↓
CORS Error? → Use Proxy Endpoint → Check Server Logs
     ↓
400 Bad Request? → Verify Metric Format → Ensure Newline Ending
     ↓
Proxy Failed? → Check Server Status → Restart if Needed
     ↓
Success! → Verify in Prometheus → Check Grafana Dashboard
```

#### Debug Commands
```bash
# Check server status
ps aux | grep "simple-server" | grep -v grep

# Check server logs
tail -f server.log

# Test Pushgateway directly
curl -X POST -d "videostutter{table_id=\"test\"} 1" \
  http://localhost:9091/metrics/job/test

# Verify metric received
curl -s http://localhost:9091/metrics | grep videostutter

# Check Prometheus targets
curl -s http://localhost:9090/api/v1/targets | grep pushgateway
```

### Dashboard Shows "No Data"

### Pushgateway Issues

If you encounter problems with Pushgateway:

1. **400 Bad Request Errors**:
   - Check metric format: `metric_name{label="value"} metric_value`
   - Ensure proper escaping of quotes in labels
   - Verify job name is correct: `studio-web-player`
   - **Important**: Metrics must end with a newline character (`\n`)

2. **Metrics Not Appearing in Prometheus**:
   - Check Pushgateway target status: `curl -s http://localhost:9090/api/v1/targets`
   - Verify Pushgateway is running: `docker compose ps`
   - Check Prometheus configuration reloaded after changes

3. **Common Solutions**:
   - Restart Prometheus: `docker compose restart prometheus`
   - Check Pushgateway logs: `docker logs kevin-telemetry-pushgateway`
   - Verify metric format with manual curl test

### Dashboard Shows "No Data"

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
