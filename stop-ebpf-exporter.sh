#!/bin/bash
# Stop eBPF Exporter service

set -e

echo "Stopping eBPF Exporter..."

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

# Stop the service
$COMPOSE_CMD stop ebpf-exporter

echo "✓ eBPF Exporter stopped"

