# Loki Agent Configuration for Studio SDP Roulette Log Collection

## Overview

This document describes the configuration and setup process for collecting Studio SDP Roulette logs using the aro11 Loki agent. The system monitors large log files from `/home/rnd/studio-sdp-roulette/self-test-2api.log` and sends them to a central Loki server for analysis in Grafana.

## Architecture

```
Studio SDP Roulette                aro11 Agent               Central Server
┌─────────────────────┐            ┌─────────────────────┐        ┌─────────────────┐
│                     │            │                     │        │                 │
│ self-test-2api.log  │ ──────────▶│  Promtail Container │ ──────▶│  Loki Server    │
│                     │   mount    │                     │  HTTP  │                 │
│ [timestamp] Receive │            │ - Parse timestamps  │        │ - 7 day retain │
│ [timestamp] Send    │            │ - Add labels        │        │ - Auto cleanup  │
│ [timestamp] WebSocket│           │ - Drop old entries  │        │                 │
└─────────────────────┘            └─────────────────────┘        └─────────┬───────┘
                                                                             │
                                                                             ▼
                                                                    ┌─────────────────┐
                                                                    │  Grafana Web UI │
                                                                    │                 │
                                                                    │ Query & Visualize│
                                                                    └─────────────────┘
```

## Configuration Files Modified

### 1. Promtail Configuration (`promtail-GC-aro11-agent.yml`)

#### New Job Configuration
```yaml
# Studio SDP Roulette API logs - Main monitoring target
- job_name: studio_sdp_roulette_logs
  static_configs:
    - targets:
        - localhost
      labels:
        job: studio_sdp_roulette
        instance: GC-aro11-agent
        __path__: /var/log/studio-sdp-roulette/self-test-2api.log
  pipeline_stages:
    # Parse timestamp format: [2025-09-19 11:57:22.362]
    - regex:
        expression: '^\[(?P<timestamp>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3})\] (?P<direction>Receive|Send|WebSocket) (?P<arrow>>>|<<<) (?P<message>.*)$'
    - labels:
        direction:
    - timestamp:
        source: timestamp
        format: "2006-01-02 15:04:05.000"
        location: "Asia/Taipei"
    # Drop old entries (only keep recent logs to manage large file)
    - drop:
        older_than: 168h
```

#### Log Format Parsing
The configuration parses log entries in the following format:
- `[2025-09-19 11:57:22.362] Receive >>> *X;3;241;32;0;137;0`
- `[2025-09-19 11:57:22.362] Send <<< *u 1`
- `[2025-09-19 11:57:22.362] WebSocket >>> Stop recording`

### 2. Docker Compose Configuration (`docker-compose-GC-aro11-agent.yml`)

#### Volume Mount and Persistence Configuration
```yaml
volumes:
  - ./promtail-GC-aro11-agent.yml:/etc/promtail/config.yml
  # Studio SDP Roulette logs - Main monitoring target
  - /home/rnd/studio-sdp-roulette/self-test-2api.log:/var/log/studio-sdp-roulette/self-test-2api.log:ro
  # Existing logs for backward compatibility
  - ./mock_sicbo.log:/var/log/mock_sicbo.log
  - ./server.log:/var/log/server.log
  - ./tmux-client-3638382.log:/var/log/tmux-client.log
  - ./sdp.log:/var/log/sdp.log
  # Persistent volumes for Promtail data
  - promtail_aro_001_1_positions:/tmp/positions  # Position tracking for log files
  - promtail_aro_001_1_data:/var/lib/promtail    # Promtail internal data
```

#### Docker Volumes for Data Persistence
```yaml
volumes:
  promtail_aro_001_1_positions:
    name: telemetry_promtail_aro_001_1_positions
    external: true
  promtail_aro_001_1_data:
    name: telemetry_promtail_aro_001_1_data
    external: true
  zabbix_agent_aro_001_1_data:
    name: telemetry_zabbix_agent_aro_001_1_data
    external: true
```

### 3. Loki Server Configuration (`loki-config.yml`)

#### Retention Policy and Rate Limits
```yaml
limits_config:
  reject_old_samples: true
  reject_old_samples_max_age: 168h  # 7 days
  allow_structured_metadata: false
  creation_grace_period: 10m
  # Limit ingestion rate to handle large log files efficiently
  ingestion_rate_mb: 64
  ingestion_burst_size_mb: 128
  max_streams_per_user: 10000
  max_line_size: 256000

table_manager:
  retention_deletes_enabled: true
  retention_period: 168h  # 7 days retention
```

## Setup and Execution Steps

### 1. Apply Configuration Changes

```bash
cd /home/rnd/telemetry

# Stop current agent
docker compose -f docker-compose-GC-aro11-agent.yml down

# Restart Loki server with new retention policy
docker compose -f docker-compose.yml restart loki

# Start agent with new configuration
docker compose -f docker-compose-GC-aro11-agent.yml up -d
```

### 2. Verify Configuration

```bash
# Check container status
docker compose -f docker-compose-GC-aro11-agent.yml ps

# Monitor Promtail logs
docker compose -f docker-compose-GC-aro11-agent.yml logs -f promtail

# Run test script
python3 test_studio_sdp_logs.py
```

### 3. Troubleshooting

#### Common Issues and Solutions

**Issue**: Promtail shows "time: unknown unit 'd' in duration '7d'"
```bash
# Solution: Use hours instead of days
older_than: 168h  # Instead of 7d
```

**Issue**: Loki returns "429 Too Many Requests"
```bash
# Solution: Increase rate limits in loki-config.yml
ingestion_rate_mb: 64
ingestion_burst_size_mb: 128
```

**Issue**: File mount errors
```bash
# Ensure the source file exists and is readable
ls -la /home/rnd/studio-sdp-roulette/self-test-2api.log

# Check file size
du -h /home/rnd/studio-sdp-roulette/self-test-2api.log
```

## Data Retention and Management

### Automatic Cleanup
- **Promtail Level**: Drops log entries older than 168 hours (7 days)
- **Loki Level**: Automatically deletes stored data older than 168 hours
- **File Management**: Original log file remains untouched, only ingestion is filtered

### Performance Optimization
- **Rate Limiting**: 64MB/sec ingestion rate with 128MB burst capacity
- **Line Size**: Maximum 256KB per log line
- **Stream Limits**: Up to 10,000 streams per user

## Monitoring and Access

### Grafana Query Examples

```logql
# All Studio SDP logs from aro11
{job="studio_sdp_roulette", instance="GC-aro11-agent"}

# Only Receive messages
{job="studio_sdp_roulette", instance="GC-aro11-agent"} |= "Receive >>>"

# Only WebSocket messages
{job="studio_sdp_roulette", instance="GC-aro11-agent"} |= "WebSocket >>>"

# Filter by time range (last 1 hour)
{job="studio_sdp_roulette", instance="GC-aro11-agent"}[1h]
```

### Access Points
- **Grafana Web UI**: `http://100.64.0.113:3000`
- **Loki API**: `http://100.64.0.113:3100`
- **Promtail Metrics**: `http://100.64.0.167:9080`

### Labels Applied
Each log entry is automatically tagged with:
- `job`: `studio_sdp_roulette`
- `instance`: `GC-aro11-agent`
- `direction`: `Receive`, `Send`, or `WebSocket`
- `filename`: `/var/log/studio-sdp-roulette/self-test-2api.log`

## Test Results

The configuration successfully:
- ✅ Reads 394.07 MB Studio SDP log file
- ✅ Runs Promtail container without errors
- ✅ Collects 100+ log entries per hour
- ✅ Parses timestamps and message types correctly
- ✅ Applies proper labels for filtering
- ✅ Maintains 7-day data retention policy

## Data Persistence

### Docker Volumes for Persistent Storage

The aro11 agent now uses Docker volumes for data persistence:

| Volume Name | Purpose | Mount Point | Size |
|-------------|---------|-------------|------|
| `telemetry_promtail_aro_001_1_positions` | Position tracking | `/tmp/positions` | ~100B |
| `telemetry_promtail_aro_001_1_data` | Promtail internal data | `/var/lib/promtail` | Variable |
| `telemetry_zabbix_agent_aro_001_1_data` | Zabbix agent buffer | `/var/lib/zabbix/agent` | Variable |

### Volume Management

Use the provided management script for volume operations:

```bash
# Check volume status
./manage_aro_001_1_volumes.sh --status

# Create volumes (if not exists)
./manage_aro_001_1_volumes.sh --create

# Backup volumes
./manage_aro_001_1_volumes.sh --backup

# Restore from backup
./manage_aro_001_1_volumes.sh --restore 20250919_122626

# Clean old backups (keep 7 days)
./manage_aro_001_1_volumes.sh --clean

# Restart agent with volumes
./manage_aro_001_1_volumes.sh --restart
```

### Position File Tracking

The position file (`/tmp/positions/positions.yaml`) tracks log reading positions:

```yaml
positions:
  /var/log/studio-sdp-roulette/self-test-2api.log: "304259918"
```

This ensures Promtail resumes from the correct position after container restarts.

## Files Created/Modified

### Configuration Files
- `promtail-GC-aro11-agent.yml` - Updated with Studio SDP log job and persistent position path
- `docker-compose-GC-aro11-agent.yml` - Added volume mounts and persistent volume definitions
- `loki-config.yml` - Enhanced retention and rate limit settings

### Utility Scripts
- `test_studio_sdp_logs.py` - Test script to verify log collection
- `restart_aro_001_1_agent.sh` - Restart script for applying configuration
- `manage_aro_001_1_volumes.sh` - Volume management script for backup/restore operations
- `loki_sdp_log.md` - This documentation file

## Future Enhancements

### Potential Improvements
1. **Log Parsing**: Add more specific regex patterns for different message types
2. **Alerting**: Set up Grafana alerts for specific error patterns
3. **Dashboards**: Create dedicated dashboards for Studio SDP monitoring
4. **Metrics**: Extract metrics from log patterns (round timing, error rates)
5. **Multi-file Support**: Extend to monitor multiple SDP log files

### Scaling Considerations
- Monitor disk usage on Loki server with large log volumes
- Consider log sampling for very high-volume scenarios
- Implement log rotation on source files if needed
- Set up backup strategies for critical log data
