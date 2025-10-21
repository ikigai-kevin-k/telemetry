# Zabbix Container Setup for Kevin Telemetry

This directory contains the configuration files for setting up Zabbix monitoring system in the telemetry project.

## Overview

The Zabbix setup includes:
- **Zabbix Server**: Main monitoring server with MySQL database
- **Zabbix Web Interface**: Web-based management interface
- **Zabbix Agent**: Agent for collecting monitoring data
- **MySQL Database**: Database for storing Zabbix configuration and data

## Container Information

- **Zabbix Server**: `kevin-telemetry-zabbix-server` (Port: 10051)
- **Zabbix Web**: `kevin-telemetry-zabbix-web` (Port: 8080)
- **Zabbix Database**: `kevin-telemetry-zabbix-db`
- **Zabbix Agent**: `kevin-telemetry-zabbix-agent`

## ZCAM Monitoring

The system includes custom scripts to monitor ZCAM status:

### Scripts

1. **`check_zcam_status.sh`**: Basic ZCAM status check
   - Returns the main status (busy, idle, error, offline)
   - Uses UserParameter: `zcam.status`

2. **`check_zcam_detailed.sh`**: Detailed ZCAM information
   - Provides comprehensive status information
   - Can be extended for additional monitoring items

### API Endpoint

The scripts monitor the ZCAM RTMP API:
```
http://192.168.88.175/ctrl/rtmp?action=query&index=0
```

### Expected Response Format

```json
{
  "url": "rtmp://192.168.88.180:1935/live/r175_bj",
  "key": "",
  "bw": 9.71285,
  "status": "busy",
  "autoRestart": 1,
  "code": 0
}
```

## Getting Started

1. **Start the containers**:
   ```bash
   docker-compose up -d
   ```

2. **Access Zabbix Web Interface**:
   - URL: http://localhost:8080
   - Username: `admin`
   - Password: `admin`

3. **Configure Host**:
   - Add a new host with name: `kevin-telemetry-zabbix-agent`
   - Use templates: `Template OS Linux by Zabbix agent`

4. **Add Custom Items**:
   - Key: `zcam.status`
   - Type: `Zabbix agent`
   - Update interval: `1m`

## Custom Monitoring Items

### ZCAM Status
- **Key**: `zcam.status`
- **Description**: ZCAM streaming status
- **Type**: `Zabbix agent`
- **Data type**: `Text`
- **Update interval**: `1m`

### Additional Items (can be added)
- **Key**: `system.run[curl -s "http://192.168.88.175/ctrl/rtmp?action=query&index=0" | jq -r '.bw']`
- **Description**: ZCAM bandwidth usage
- **Type**: `Zabbix agent`
- **Data type**: `Numeric (float)`
- **Units**: `Mbps`

## Troubleshooting

### Check Agent Status
```bash
docker exec kevin-telemetry-zabbix-agent zabbix_agent2 -t "zcam.status"
```

### Check Script Execution
```bash
docker exec kevin-telemetry-zabbix-agent /var/lib/zabbix/scripts/check_zcam_status.sh
```

### View Agent Logs
```bash
docker logs kevin-telemetry-zabbix-agent
```

### Check Server Logs
```bash
docker logs kevin-telemetry-zabbix-server
```

## Security Notes

- Default passwords are set for development purposes
- In production, change all default passwords
- Consider using environment variables for sensitive data
- Restrict network access to Zabbix services

## Dependencies

- Docker and Docker Compose
- curl (for API calls)
- jq (optional, for JSON parsing)
- bash (for script execution)

## Network Configuration

All containers are connected to the `monitoring` network, which allows:
- Communication between Zabbix components
- Integration with existing monitoring stack (Prometheus, Grafana)
- Isolated network environment
