# asb11 Agent Setup

## Overview
asb11 agent has been configured to monitor SBO001 log files with dynamic date patterns, based on the configuration from aro11 and aro21 agents.

## Key Features

### 1. Dynamic SBO001 Log Monitoring
- **Path**: `/home/rnd/studio-sdp-roulette/logs/SBO001_*.log`
- **Pattern**: Automatically detects SBO001 files with any date suffix (e.g., SBO001_0918.log, SBO001_0919.log)
- **Format**: Parses timestamp format `[2025-09-19 11:57:22.362]`

### 2. Log Processing Pipeline
- **Regex parsing** for timestamp, direction, and message extraction
- **Timezone**: Asia/Taipei
- **Retention**: Drops entries older than 168 hours (7 days)
- **Labels**: job=studio_sdp_roulette, instance=GC-asb11-agent

### 3. Persistent Storage
- **Promtail positions**: `promtail_asb_001_1_positions` volume
- **Promtail data**: `promtail_asb_001_1_data` volume
- **Zabbix data**: `zabbix_agent_asb_001_1_data` volume

## Files Modified

### Configuration Files
- `promtail-GC-asb11-agent.yml` - Updated with studio_sdp_roulette_logs job
- `docker-compose-GC-asb11-agent.yml` - Added dynamic log volume mounting

### Scripts Created
- `scripts/get-latest-sbo-log.sh` - Find latest SBO001 log file
- `start-asb11-agent.sh` - Start agent with log validation

## Usage

### Start Agent
```bash
./start-asb11-agent.sh
```

### Check Latest Log
```bash
./scripts/get-latest-sbo-log.sh /home/rnd/studio-sdp-roulette/logs --info
```

### View Logs
```bash
docker compose -f docker-compose-GC-asb11-agent.yml logs -f promtail
```

### Stop Agent
```bash
docker compose -f docker-compose-GC-asb11-agent.yml down
```

## Log Monitoring Status

The agent automatically monitors all SBO001_*.log files in the logs directory:
- **Current files detected**: SBO001_0915.log, SBO001_0918.log, SBO001_0919.log
- **Log format**: `[YYYY-MM-DD HH:MM:SS.mmm] Direction >>> Message`
- **Data destination**: Loki server at 100.64.0.113:3100

## Troubleshooting

### Check Promtail Status
```bash
docker compose -f docker-compose-GC-asb11-agent.yml logs promtail
```

### Verify Log Files
```bash
ls -la /home/rnd/studio-sdp-roulette/logs/SBO001_*.log
```

### Test Configuration
```bash
docker run --rm -v $(pwd)/promtail-GC-asb11-agent.yml:/etc/promtail/config.yml grafana/promtail:latest -config.file=/etc/promtail/config.yml -dry-run
```

## Integration Details

### Loki Server
- **URL**: http://100.64.0.113:3100/loki/api/v1/push
- **Job Labels**: studio_sdp_roulette, mock_sicbo, server, tmux_client, sdp
- **Instance**: GC-asb11-agent

### Zabbix Agent
- **Server**: 100.64.0.113:10051
- **Hostname**: GC-asb11-agent
- **Port**: 10050

## Success Confirmation

✅ Agent successfully started and monitoring SBO001 log files
✅ Dynamic date pattern working (SBO001_*.log)
✅ Promtail configuration validated
✅ Docker containers running properly
✅ Log files being tailed and processed
