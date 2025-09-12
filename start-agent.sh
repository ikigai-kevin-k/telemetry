#!/bin/bash

# Start Agent Mode - Run on 100.64.0.149 (GC-ARO-001-2)
# This script starts: Loki Agent (Promtail), Zabbix Agent

echo "Starting Telemetry Agent Mode..."
echo "Agent IP: 100.64.0.149"
echo "Services: Loki Agent (Promtail), Zabbix Agent"
echo "Connecting to Server: 100.64.0.160"
echo ""

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null; then
    echo "Error: docker-compose is not installed or not in PATH"
    exit 1
fi

# Start agent services
echo "Starting agent services..."
docker-compose -f docker-compose.agent.yml up -d

echo ""
echo "Agent services started successfully!"
echo ""
echo "Agent Configuration:"
echo "- Promtail: Collecting logs and sending to 100.64.0.160:3100"
echo "- Zabbix Agent: Connecting to 100.64.0.160:10051"
echo "- Log files being monitored:"
echo "  - /var/log/mock_sicbo.log"
echo "  - /var/log/server.log"
echo "  - /var/log/tmux-client.log"
echo ""
echo "To view logs: docker-compose -f docker-compose.agent.yml logs -f"
echo "To stop services: docker-compose -f docker-compose.agent.yml down"
