#!/bin/bash
# Start eBPF Exporter service

set -e

echo "Starting eBPF Exporter..."

# Check if docker compose is available
if command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
elif command -v docker &> /dev/null && docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
else
    echo "Error: docker compose or docker-compose not found"
    exit 1
fi

# Navigate to project directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Build and start the service
echo "Building eBPF Exporter image..."
$COMPOSE_CMD build ebpf-exporter

echo "Starting eBPF Exporter container..."
$COMPOSE_CMD up -d ebpf-exporter

# Wait for service to be ready
echo "Waiting for service to start..."
sleep 5

# Check if service is running
if docker ps | grep -q "kevin-telemetry-ebpf-exporter"; then
    echo "✓ eBPF Exporter is running"
    
    # Test metrics endpoint
    if curl -s http://localhost:9300/metrics | grep -q "ebpf"; then
        echo "✓ Metrics endpoint is accessible"
        echo ""
        echo "Service URL: http://localhost:9300/metrics"
        echo "Health check: http://localhost:9300/health"
        echo ""
        echo "To view logs: docker logs -f kevin-telemetry-ebpf-exporter"
    else
        echo "⚠ Warning: Metrics endpoint might not be ready yet"
        echo "Check logs: docker logs kevin-telemetry-ebpf-exporter"
    fi
else
    echo "✗ Failed to start eBPF Exporter"
    echo "Check logs: docker logs kevin-telemetry-ebpf-exporter"
    exit 1
fi

