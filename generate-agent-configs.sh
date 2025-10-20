#!/bin/bash

# Generate agent configuration files
# Usage: ./generate-agent-configs.sh <agent_name> <agent_ip>
# Example: ./generate-agent-configs.sh GC-asb11-agent 100.64.0.166

AGENT_NAME="$1"
AGENT_IP="$2"

if [ -z "$AGENT_NAME" ] || [ -z "$AGENT_IP" ]; then
    echo "Error: Missing required parameters"
    echo "Usage: $0 <agent_name> <agent_ip>"
    echo "Example: $0 GC-asb11-agent 100.64.0.166"
    exit 1
fi

SERVER_IP="100.64.0.113"
SERVER_LOKI_PORT="3100"
SERVER_ZABBIX_PORT="10051"

echo "Generating configuration files for agent: $AGENT_NAME (IP: $AGENT_IP)"

# Generate Promtail configuration
PROMTAIL_CONFIG="promtail-${AGENT_NAME}.yml"
echo "Creating Promtail configuration: $PROMTAIL_CONFIG"

cat > "$PROMTAIL_CONFIG" << EOF
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://${SERVER_IP}:${SERVER_LOKI_PORT}/loki/api/v1/push  # Connect to remote Loki server

scrape_configs:
  - job_name: mock_sicbo_logs
    static_configs:
      - targets:
          - localhost
        labels:
          job: mock_sicbo
          instance: ${AGENT_NAME}  # Agent instance identifier
          __path__: /var/log/mock_sicbo.log
    pipeline_stages:
      - regex:
          expression: '^(?P<timestamp>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}) - (?P<logger>\w+) - (?P<level>\w+) - (?P<message>.*)$'
      - labels:
          level:
          logger:
      - timestamp:
          source: timestamp
          format: "2006-01-02 15:04:05"
          location: "Asia/Taipei"

  - job_name: server_logs
    static_configs:
      - targets:
          - localhost
        labels:
          job: server
          instance: ${AGENT_NAME}
          __path__: /var/log/server.log
    pipeline_stages:
      - timestamp:
          source: time
          format: RFC3339
          location: "Asia/Taipei"

  - job_name: tmux_client_logs
    static_configs:
      - targets:
          - localhost
        labels:
          job: tmux_client
          instance: ${AGENT_NAME}
          __path__: /var/log/tmux-client.log
    pipeline_stages:
      - timestamp:
          source: time
          format: RFC3339
          location: "Asia/Taipei"

  - job_name: sdp_logs
    static_configs:
      - targets:
          - localhost
        labels:
          job: sdp
          instance: ${AGENT_NAME}
          service: sdp_service
          __path__: /var/log/sdp.log
    pipeline_stages:
      - regex:
          expression: '^(?P<timestamp>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}) - (?P<logger>\w+) - (?P<level>\w+) - (?P<game_type>\w+) - (?P<table_name>.*?) - (?P<error_code>\w+) - (?P<error_message>.*)$'
      - labels:
          level:
          logger:
          game_type:
          table_name:
          error_code:
      - timestamp:
          source: timestamp
          format: "2006-01-02 15:04:05"
          location: "Asia/Taipei"
EOF

# Generate Zabbix Agent configuration
ZABBIX_CONFIG="zabbix/agent2-${AGENT_NAME}.conf"
echo "Creating Zabbix Agent configuration: $ZABBIX_CONFIG"

mkdir -p zabbix

cat > "$ZABBIX_CONFIG" << EOF
# Zabbix Agent2 Configuration File for ${AGENT_NAME}
# This file is used to configure the Zabbix Agent2

# Basic agent settings
Server=${SERVER_IP},172.18.0.1
ServerActive=${SERVER_IP}
Hostname=${AGENT_NAME}

# Enable persistent buffer
EnablePersistentBuffer=1
PersistentBufferFile=/var/lib/zabbix/agent2_persistent_buffer.db

# Log settings
LogType=console

# Custom script directory
UserParameter=zcam.status,/var/lib/zabbix/scripts/check_zcam_status.sh

# System monitoring parameters
UserParameter=system.cpu.usage,/var/lib/zabbix/scripts/system_monitor.sh cpu_usage
UserParameter=system.memory.usage,/var/lib/zabbix/scripts/system_monitor.sh memory_usage
UserParameter=system.disk.usage,/var/lib/zabbix/scripts/system_monitor.sh disk_usage
UserParameter=system.disk.usage.mount[*],/var/lib/zabbix/scripts/system_monitor.sh disk_usage_mount \$1
UserParameter=system.load.average,/var/lib/zabbix/scripts/system_monitor.sh load_average
# UserParameter=system.uptime,/var/lib/zabbix/scripts/system_monitor.sh uptime  # Commented out - conflicts with built-in key
UserParameter=system.temperature,/var/lib/zabbix/scripts/system_monitor.sh temperature
UserParameter=system.network.status[*],/var/lib/zabbix/scripts/system_monitor.sh network_status \$1
UserParameter=system.health.score,/var/lib/zabbix/scripts/system_monitor.sh system_health

# System warning parameters
UserParameter=system.cpu.warning,/var/lib/zabbix/scripts/system_monitor.sh cpu_warning
UserParameter=system.memory.warning,/var/lib/zabbix/scripts/system_monitor.sh memory_warning
UserParameter=system.disk.warning,/var/lib/zabbix/scripts/system_monitor.sh disk_warning
UserParameter=system.temperature.warning,/var/lib/zabbix/scripts/system_monitor.sh temperature_warning
UserParameter=system.high.load,/var/lib/zabbix/scripts/system_monitor.sh high_load

# Power monitoring parameters
UserParameter=power.battery.status,/var/lib/zabbix/scripts/power_monitor.sh battery_power
UserParameter=power.battery.charge,/var/lib/zabbix/scripts/power_monitor.sh battery_charge
EOF

# Generate Docker Compose configuration
DOCKER_COMPOSE_FILE="docker-compose-${AGENT_NAME}.yml"
echo "Creating Docker Compose configuration: $DOCKER_COMPOSE_FILE"

cat > "$DOCKER_COMPOSE_FILE" << EOF
version: '3.8'

# Agent Mode - Run on ${AGENT_IP} (${AGENT_NAME})
# This compose file runs: Loki Agent (Promtail), Zabbix Agent

services:
  # Loki Agent (Promtail) - Collects logs and sends to remote Loki server
  promtail:
    image: grafana/promtail:latest
    container_name: telemetry-promtail-${AGENT_NAME}
    volumes:
      - ./${PROMTAIL_CONFIG}:/etc/promtail/config.yml
      - ./mock_sicbo.log:/var/log/mock_sicbo.log
      - ./server.log:/var/log/server.log  # Additional log file
      - ./tmux-client-3638382.log:/var/log/tmux-client.log  # Additional log file
      - ./sdp.log:/var/log/sdp.log  # SDP error logs
    command: -config.file=/etc/promtail/config.yml
    restart: unless-stopped
    networks:
      - monitoring

  # Zabbix Agent - Connects to remote Zabbix server
  zabbix-agent:
    image: zabbix/zabbix-agent2:ubuntu-6.0-latest
    container_name: telemetry-zabbix-agent-${AGENT_NAME}
    ports:
      - "10050:10050"
    environment:
      - ZBX_HOSTNAME=${AGENT_NAME}
      - ZBX_SERVER_HOST=${SERVER_IP}  # Connect to remote Zabbix server
      - ZBX_SERVER_ACTIVE=${SERVER_IP}
      - ZBX_SERVER_PORT=${SERVER_ZABBIX_PORT}
      - ZBX_ENABLEPERSISTENTBUFFER=1
    volumes:
      - ./${ZABBIX_CONFIG}:/etc/zabbix/zabbix_agent2.conf
      - ./zabbix/scripts:/var/lib/zabbix/scripts
    restart: unless-stopped
    networks:
      - monitoring

networks:
  monitoring:
    driver: bridge
EOF

echo "Configuration files generated successfully!"
echo "- Promtail config: $PROMTAIL_CONFIG"
echo "- Zabbix config: $ZABBIX_CONFIG"
echo "- Docker Compose: $DOCKER_COMPOSE_FILE"
