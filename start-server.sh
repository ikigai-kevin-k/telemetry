#!/bin/bash

# Start Server Mode - Support GE (100.64.0.113) and TPE (100.64.0.160) servers
# This script starts: Loki Server, Zabbix Server/Web, Prometheus, Grafana
# Usage: ./start-server.sh [ge|tpe]
#        ./start-server.sh ge   - Start on GE server (100.64.0.113) - default
#        ./start-server.sh tpe  - Start on TPE server (100.64.0.160)

# Default to GE server
SERVER_TYPE=${1:-ge}

# Set server IP based on type
case $SERVER_TYPE in
    "ge"|"GE")
        SERVER_IP="100.64.0.113"
        SERVER_NAME="GE (GC-ARO-002-1)"
        ;;
    "tpe"|"TPE")
        SERVER_IP="100.64.0.160"
        SERVER_NAME="TPE"
        ;;
    *)
        echo "Error: Invalid server type '$SERVER_TYPE'"
        echo "Usage: $0 [ge|tpe]"
        echo "  ge  - Start on GE server (100.64.0.113) - default"
        echo "  tpe - Start on TPE server (100.64.0.160)"
        exit 1
        ;;
esac

echo "Starting Telemetry Server Mode..."
echo "Server: $SERVER_NAME ($SERVER_IP)"
echo "Services: Loki Server, Zabbix Server/Web, Prometheus, Grafana"
echo ""

# Check if docker compose is available
if ! command -v docker &> /dev/null; then
    echo "Error: docker is not installed or not in PATH"
    exit 1
fi

# Export SERVER_IP for docker compose
export SERVER_IP

# Start server services
echo "Starting server services..."
docker compose up -d

echo ""
echo "Server services started successfully!"
echo ""
echo "Service URLs:"
echo "- Grafana: http://$SERVER_IP:3000 (admin/admin)"
echo "- Prometheus: http://$SERVER_IP:9090"
echo "- Alertmanager: http://$SERVER_IP:9093"
echo "- Loki Server: http://$SERVER_IP:3100"
echo "- Zabbix Web: http://$SERVER_IP:8080"
echo "- Zabbix Server: $SERVER_IP:10051"
echo "- Pushgateway: http://$SERVER_IP:9091"
echo ""
echo "To view logs: docker compose logs -f"
echo "To stop services: docker compose down"
echo ""
echo "To start on different server:"
echo "  ./start-server.sh ge   - GE server (100.64.0.113)"
echo "  ./start-server.sh tpe  - TPE server (100.64.0.160)"
