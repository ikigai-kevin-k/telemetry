# Telegraf ZCAM Dashboard Setup Guide

## 📋 Overview

This guide documents the complete setup process for monitoring ZCAM devices using Telegraf's `http_response` plugin, with data visualization through Prometheus and Grafana dashboard. This implementation follows the methodology from [Grafana HTTP Response Monitoring Dashboard](https://grafana.com/grafana/dashboards/11777-http-response-monitoring/).

## 🏗️ Architecture

```
ZCAM Devices (5x) → Telegraf (http_response plugin) → Prometheus → Grafana Dashboard
```

### Component Details
- **ZCAM Devices**: 5 camera devices with HTTP APIs
- **Telegraf**: Collects HTTP response metrics from ZCAM APIs
- **Prometheus**: Stores and serves metrics data
- **Grafana**: Visualizes HTTP response monitoring data

## 🎯 Device Mapping

| Device Name | IP Address | Agent | RTMP Server | Stream Key |
|-------------|------------|-------|-------------|------------|
| zcam-aro-001-1 | 192.168.88.184 | aro-001-1 | 192.168.88.26 | r184_sr |
| zcam-aro-001-2 | 192.168.88.186 | aro-001-2 | 192.168.88.27 | r186_sr |
| zcam-aro-002-1 | 192.168.88.183 | aro-002-1 | 192.168.88.84 | r183_vr |
| zcam-aro-002-2 | 192.168.88.34 | aro-002-2 | 192.168.88.50 | r034_vr |
| zcam-asb-001-1 | 192.168.88.212 | asb-001-1 | 192.168.88.10 | r212_sb |

## 📁 Configuration Files

### 1. **Telegraf Configuration**
**File**: `telegraf/telegraf-zcam.conf`

Key configuration sections:
```toml
# Global settings
[global_tags]
  environment = "production"
  service = "zcam-monitoring"

[agent]
  interval = "30s"
  flush_interval = "10s"

# Output to Prometheus
[[outputs.prometheus_client]]
  listen = ":9273"
  metric_version = 2

# HTTP Response monitoring for each ZCAM device (3 endpoints per device)
[[inputs.http_response]]
  urls = ["http://192.168.88.184/ctrl/rtmp?action=query&index=0"]
  response_timeout = "5s"
  method = "GET"
  [inputs.http_response.tags]
    device_name = "zcam-aro-001-1"
    agent_name = "aro-001-1"
    endpoint_type = "rtmp_status"
```

### 2. **Docker Compose Configuration**
**File**: `docker-compose-telegraf.yml`

```yaml
services:
  telegraf-zcam:
    image: telegraf:1.28-alpine
    container_name: kevin-telemetry-telegraf-zcam
    restart: unless-stopped
    volumes:
      - ./telegraf/telegraf-zcam.conf:/etc/telegraf/telegraf.conf:ro
    ports:
      - "9273:9273"  # Prometheus metrics endpoint
    networks:
      - monitoring
```

### 3. **Prometheus Configuration Update**
**File**: `prometheus.yml`

Added scrape configuration:
```yaml
scrape_configs:
  - job_name: 'telegraf-zcam'
    static_configs:
      - targets: ['kevin-telemetry-telegraf-zcam:9273']
    metrics_path: '/metrics'
    scrape_interval: 30s
    scrape_timeout: 10s
```

### 4. **Grafana Dashboard Configuration**
**File**: `grafana/provisioning/dashboards/zcam/zcam-http-response-monitoring.json`

Dashboard includes 5 panels:
- ZCAM API Response Time (Time Series)
- ZCAM API Status Overview (Table)
- ZCAM API Health Status (Stat)
- ZCAM API Response Content Length (Time Series)
- ZCAM API Response Time Details (Table)

### 5. **Dashboard Provisioning Configuration**
**File**: `grafana/provisioning/dashboards/dashboard.yml`

Added ZCAM dashboard provider:
```yaml
providers:
  - name: 'zcam-dashboards'
    orgId: 1
    folder: 'ZCAM'
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /etc/grafana/provisioning/dashboards/zcam
```

## 🔧 Setup Process

### **Step 1: Create Telegraf Configuration**
```bash
# Create telegraf directory
mkdir -p /home/ella/kevin/telemetry/telegraf

# Create telegraf-zcam.conf with http_response plugin configuration
# Configure monitoring for 5 ZCAM devices, 3 endpoints each (15 total)
```

### **Step 2: Deploy Telegraf Service**
```bash
# Deploy Telegraf container
cd /home/ella/kevin/telemetry
docker-compose -f docker-compose-telegraf.yml up -d

# Verify Telegraf is running
docker ps --filter "name=telegraf"
```

### **Step 3: Update Prometheus Configuration**
```bash
# Add telegraf-zcam job to prometheus.yml
# Restart Prometheus to load new configuration
docker restart kevin-telemetry-prometheus
```

### **Step 4: Configure Grafana Dashboard**
```bash
# Create ZCAM dashboard directory
mkdir -p grafana/provisioning/dashboards/zcam

# Add dashboard JSON configuration
# Update dashboard.yml to include ZCAM dashboards
# Restart Grafana
docker restart kevin-telemetry-grafana
```

### **Step 5: Fix Data Source UID**
```bash
# Get correct Prometheus datasource UID from Grafana API
curl -s "http://100.64.0.113:3000/api/datasources" -u "admin:admin" | \
  jq '.[] | select(.type=="prometheus") | {name, uid, url}'

# Update dashboard JSON with correct UID: PBFA97CFB590B2093
# Restart Grafana to apply changes
```

## 📊 Collected Metrics

### **HTTP Response Metrics**
Telegraf collects the following metrics for each ZCAM API endpoint:

1. **`http_response_response_time`** - API response time in seconds
2. **`http_response_http_response_code`** - HTTP status code (200, 404, etc.)
3. **`http_response_result_code`** - Success/failure indicator (0=success, 1=failure)
4. **`http_response_content_length`** - Response content length in bytes

### **Monitored API Endpoints**
For each ZCAM device, 3 endpoints are monitored:

| Endpoint Type | API Path | Purpose |
|---------------|----------|---------|
| rtmp_status | `/ctrl/rtmp?action=query&index=0` | RTMP streaming status |
| battery | `/ctrl/get?k=battery` | Battery level monitoring |
| camera_mode | `/ctrl/mode` | Camera mode (rec/photo) |

### **Metric Labels**
Each metric includes the following labels:
- `device_name`: ZCAM device identifier
- `agent_name`: Corresponding Zabbix agent
- `device_ip`: Device IP address
- `endpoint_type`: API endpoint type
- `environment`: Environment tag (production)
- `service`: Service tag (zcam-monitoring)
- `job`: Prometheus job name (telegraf-zcam)

## 💾 Persistent Storage Configuration

### **Docker Volume Mapping**

| Service | Volume | Mount Point | Purpose |
|---------|--------|-------------|---------|
| Grafana | `telemetry_grafana_data` | `/var/lib/grafana` | Dashboards, settings, plugins |
| Prometheus | `telemetry_prometheus_data` | `/prometheus` | Metrics data storage |
| Telegraf | Bind mount | `/etc/telegraf/telegraf.conf` | Configuration file |

### **Configuration File Persistence**

| File | Mount Type | Persistence |
|------|------------|-------------|
| `telegraf/telegraf-zcam.conf` | Bind mount | ✅ Host filesystem |
| `prometheus.yml` | Bind mount | ✅ Host filesystem |
| `grafana/provisioning/dashboards/zcam/` | Bind mount | ✅ Host filesystem |
| `grafana/provisioning/dashboards/dashboard.yml` | Bind mount | ✅ Host filesystem |

## 📈 Dashboard Panels

### **Panel 1: ZCAM API Response Time** (Time Series)
- **Query**: `http_response_response_time{job="telegraf-zcam"}`
- **Visualization**: Line chart showing response time trends
- **Unit**: Seconds
- **Legend**: `{{device_name}} - {{endpoint_type}}`

### **Panel 2: ZCAM API Status Overview** (Table)
- **Query**: `http_response_http_response_code{job="telegraf-zcam"}`
- **Visualization**: Table showing HTTP status codes
- **Mapping**: 200 = "200 OK" (green)
- **Columns**: Device Name, Agent, IP Address, Endpoint Type, Status Code

### **Panel 3: ZCAM API Health Status** (Stat)
- **Query**: `http_response_result_code{job="telegraf-zcam"}`
- **Visualization**: Stat panels with background color
- **Mapping**: 0 = "SUCCESS" (green), 1 = "FAILED" (red)
- **Layout**: Grid of 15 status indicators (5 devices × 3 endpoints)

### **Panel 4: ZCAM API Response Content Length** (Time Series)
- **Query**: `http_response_content_length{job="telegraf-zcam"}`
- **Visualization**: Line chart showing response size trends
- **Unit**: Bytes

### **Panel 5: ZCAM API Response Time Details** (Table)
- **Query**: `http_response_response_time{job="telegraf-zcam"}`
- **Visualization**: Detailed table view
- **Columns**: Device Name, Agent, IP Address, API Endpoint, Response Time

## 🚀 Deployment Status

### **Current Operational Status** ✅

| Component | Status | Details |
|-----------|--------|---------|
| Telegraf | ✅ Running | Container: kevin-telemetry-telegraf-zcam |
| Prometheus | ✅ Running | Scraping telegraf-zcam job successfully |
| Grafana | ✅ Running | ZCAM dashboard loaded and functional |
| ZCAM Devices | ✅ All Online | 5/5 devices responding (HTTP 200) |

### **Metrics Collection Status**
- **Total Endpoints Monitored**: 15 (5 devices × 3 endpoints)
- **Collection Interval**: 30 seconds
- **All HTTP Status Codes**: 200 OK
- **All Result Codes**: 0 (Success)
- **Response Times**: 0.002-1.026 seconds range

## 🔍 Troubleshooting Steps Performed

### **Issue 1: Prometheus Storage Corruption**
**Error**: "segments are not sequential"
**Solution**: 
```bash
docker-compose down
docker volume rm telemetry_prometheus_data
docker-compose up -d
```

### **Issue 2: Grafana Data Source UID Mismatch**
**Error**: "Datasource prometheus was not found"
**Solution**:
```bash
# Get correct Prometheus UID
curl -s "http://100.64.0.113:3000/api/datasources" -u "admin:admin" | \
  jq '.[] | select(.type=="prometheus") | .uid'

# Update dashboard JSON with correct UID: PBFA97CFB590B2093
```

### **Issue 3: Dashboard Not Loading**
**Error**: Dashboard not appearing in Grafana UI
**Solution**:
```bash
# Add ZCAM dashboard provider to dashboard.yml
# Restart Grafana to load configuration
docker restart kevin-telemetry-grafana
```

## 🎯 Monitoring Capabilities

### **Available ZCAM API Endpoints**
Based on comprehensive testing:

| Parameter | Endpoint | Status | Description |
|-----------|----------|--------|-------------|
| ✅ battery | `/ctrl/get?k=battery` | Supported | Battery level (0-100%) |
| ✅ resolution | `/ctrl/get?k=resolution` | Supported | Video resolution settings |
| ✅ iso | `/ctrl/get?k=iso` | Supported | ISO sensitivity |
| ✅ wb | `/ctrl/get?k=wb` | Supported | White balance |
| ✅ focus | `/ctrl/get?k=focus` | Supported | Focus mode (MF/AF) |
| ✅ RTMP status | `/ctrl/rtmp?action=query&index=0` | Supported | Streaming status |
| ✅ Camera mode | `/ctrl/mode` | Supported | Recording/photo mode |
| ❌ temperature | `/ctrl/get?k=temperature` | Not supported | Temperature monitoring |
| ❌ thermal | `/ctrl/get?k=thermal` | Not supported | Thermal status |

### **Temperature Monitoring Status**
**Result**: ❌ **No temperature-related APIs available**

After comprehensive testing of 20+ potential temperature parameters:
- All temperature-related parameters return: `{"code":-1,"desc":"Key is not supported","msg":""}`
- Official ZCAM API documentation does not include temperature monitoring
- Alternative endpoints (`/ctrl/status`, `/ctrl/info`, `/ctrl/system`) do not provide temperature data

## 🔧 Alternative Monitoring Solutions

Since ZCAM devices do not provide temperature APIs, consider these alternatives:

1. **System-level monitoring**: Monitor host system temperature via Zabbix agents
2. **Performance monitoring**: Monitor API response times (may indicate thermal issues)
3. **Network stability**: Monitor connection stability (thermal issues can affect network)
4. **Stream quality**: Monitor RTMP bandwidth and stream stability

## 💾 Persistent Storage Verification

### **Docker Volume Status** ✅

| Volume | Size | Mount Point | Status |
|--------|------|-------------|--------|
| `telemetry_grafana_data` | Active | `/var/lib/grafana` | ✅ Dashboard data persisted |
| `telemetry_prometheus_data` | Active | `/prometheus` | ✅ Metrics data persisted |

### **Configuration File Persistence** ✅

| Configuration File | Mount Type | Persistence Status |
|-------------------|------------|-------------------|
| `telegraf/telegraf-zcam.conf` | Bind mount | ✅ Host filesystem |
| `prometheus.yml` | Bind mount | ✅ Host filesystem |
| `grafana/provisioning/dashboards/zcam/` | Bind mount | ✅ Host filesystem |
| `grafana/provisioning/dashboards/dashboard.yml` | Bind mount | ✅ Host filesystem |

## 📊 Current Monitoring Results

### **Health Status Summary**
- **Total API Endpoints**: 15 (5 devices × 3 endpoints each)
- **Healthy Endpoints**: 15/15 (100%)
- **HTTP Status**: All returning 200 OK
- **Result Codes**: All returning 0 (Success)
- **Average Response Time**: ~0.5 seconds

### **Per-Device Status**

#### **ZCAM ARO-001-1 (192.168.88.184)**
- ✅ RTMP API: 200 OK (1.025s response time)
- ✅ Battery API: 200 OK (0.002s response time)
- ✅ Mode API: 200 OK (0.002s response time)

#### **ZCAM ARO-001-2 (192.168.88.186)**
- ✅ RTMP API: 200 OK (0.002s response time)
- ✅ Battery API: 200 OK (1.025s response time)
- ✅ Mode API: 200 OK (0.002s response time)

#### **ZCAM ARO-002-1 (192.168.88.183)**
- ✅ RTMP API: 200 OK (1.025s response time)
- ✅ Battery API: 200 OK (0.002s response time)
- ✅ Mode API: 200 OK (0.002s response time)

#### **ZCAM ARO-002-2 (192.168.88.34)**
- ✅ RTMP API: 200 OK (0.002s response time)
- ✅ Battery API: 200 OK (0.002s response time)
- ✅ Mode API: 200 OK (1.025s response time)

#### **ZCAM ASB-001-1 (192.168.88.212)**
- ✅ RTMP API: 200 OK (1.026s response time)
- ✅ Battery API: 200 OK (0.002s response time)
- ✅ Mode API: 200 OK (0.002s response time)

## 🚨 Alerting Recommendations

### **Prometheus Alert Rules**
```yaml
groups:
  - name: zcam_http_monitoring
    rules:
      - alert: ZCAMAPIDown
        expr: http_response_result_code{job="telegraf-zcam"} > 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "ZCAM API endpoint is down"
          description: "{{$labels.device_name}} {{$labels.endpoint_type}} API is not responding"
      
      - alert: ZCAMAPISlowResponse
        expr: http_response_response_time{job="telegraf-zcam"} > 5
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "ZCAM API slow response"
          description: "{{$labels.device_name}} {{$labels.endpoint_type}} API response time is {{$value}}s"
      
      - alert: ZCAMAPIStatusCodeError
        expr: http_response_http_response_code{job="telegraf-zcam"} != 200
        for: 30s
        labels:
          severity: critical
        annotations:
          summary: "ZCAM API HTTP error"
          description: "{{$labels.device_name}} {{$labels.endpoint_type}} returned HTTP {{$value}}"
```

### **Grafana Alert Thresholds**
- **HTTP Status Code ≠ 200**: Immediate alert
- **Response Time > 5 seconds**: Warning alert
- **Result Code ≠ 0**: Critical alert

## 🔍 Verification Commands

### **Check Telegraf Metrics**
```bash
curl -s http://localhost:9273/metrics | grep "http_response"
```

### **Check Prometheus Targets**
```bash
curl -s "http://localhost:9090/api/v1/targets" | \
  jq '.data.activeTargets[] | select(.job=="telegraf-zcam")'
```

### **Query ZCAM Metrics**
```bash
curl -s "http://localhost:9090/api/v1/query?query=http_response_response_time" | \
  jq '.data.result[0:3]'
```

### **Test Individual ZCAM APIs**
```bash
curl -s "http://192.168.88.184/ctrl/rtmp?action=query&index=0"
curl -s "http://192.168.88.184/ctrl/get?k=battery"
curl -s "http://192.168.88.184/ctrl/mode"
```

## 🚀 Access Information

### **Service Endpoints**
- **Grafana Dashboard**: http://100.64.0.113:3000 (admin/admin)
- **Prometheus UI**: http://100.64.0.113:9090
- **Telegraf Metrics**: http://localhost:9273/metrics
- **ZCAM Dashboard**: Navigate to "ZCAM" folder in Grafana

### **Dashboard Features**
- **Real-time monitoring**: 30-second refresh interval
- **Multi-device support**: All 5 ZCAM devices in single dashboard
- **Color-coded status**: Green=healthy, Red=error
- **Response time tracking**: Historical trend analysis
- **Table views**: Detailed status information

## 📝 Maintenance Guidelines

### **Regular Checks**
- Monitor Telegraf container logs: `docker logs kevin-telemetry-telegraf-zcam`
- Verify Prometheus targets: http://100.64.0.113:9090/targets
- Check Grafana dashboard functionality weekly

### **Backup Recommendations**
- Configuration files are already persisted via bind mounts
- Docker volumes are automatically backed up with the system
- Export dashboard JSON periodically for version control

### **Scaling Considerations**
- To add new ZCAM devices: Update `telegraf/telegraf-zcam.conf`
- Restart Telegraf container after configuration changes
- Dashboard will automatically detect new devices via Prometheus labels

## ⚠️ Known Limitations

1. **No Temperature Monitoring**: ZCAM devices do not expose temperature APIs
2. **HTTP-only Monitoring**: Limited to API availability and response metrics
3. **No Deep Device Metrics**: Cannot access internal device statistics
4. **Dependency on Network**: Monitoring requires network connectivity to ZCAM devices

## 🎯 Future Enhancements

### **Potential Improvements**
1. **Custom ZCAM Metrics**: Develop custom exporter for deeper device insights
2. **Stream Quality Monitoring**: Parse RTMP response for bandwidth/quality metrics
3. **Battery Trend Analysis**: Extract battery level from API responses
4. **Automated Device Discovery**: Auto-discover ZCAM devices on network
5. **Integration with Zabbix**: Combine HTTP monitoring with Zabbix device monitoring

---

**Created**: 2025-09-19  
**Last Updated**: 2025-09-19  
**Status**: ✅ Production Ready  
**Reference**: [Grafana HTTP Response Monitoring Dashboard](https://grafana.com/grafana/dashboards/11777-http-response-monitoring/)
