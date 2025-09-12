#!/bin/bash

# Start Server Mode - Run on 100.64.0.160 (GC-ARO-002-1)
# This script starts: Loki Server, Zabbix Server/Web, Prometheus, Grafana

echo "Starting Telemetry Server Mode..."
echo "Server IP: 100.64.0.160"
echo "Services: Loki Server, Zabbix Server/Web, Prometheus, Grafana"
echo ""

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null; then
    echo "Error: docker-compose is not installed or not in PATH"
    exit 1
fi

# Start server services
echo "Starting server services..."
docker-compose up -d

echo ""
echo "Server services started successfully!"
echo ""
echo "Service URLs:"
echo "- Grafana: http://100.64.0.160:3000 (admin/admin)"
echo "- Prometheus: http://100.64.0.160:9090"
echo "- Loki Server: http://100.64.0.160:3100"
echo "- Zabbix Web: http://100.64.0.160:8080"
echo "- Zabbix Server: 100.64.0.160:10051"
echo ""
echo "To view logs: docker-compose logs -f"
echo "To stop services: docker-compose down"
