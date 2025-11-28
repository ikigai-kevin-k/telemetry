#!/bin/bash
# Setup script to ensure ZCAM Values Exporter starts automatically on boot
# This script configures systemd service for GC-ARO-001-2 agent

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_NAME="telemetry-agent-GC-ARO-001-2.service"
SERVICE_FILE="${SCRIPT_DIR}/${SERVICE_NAME}"
SYSTEMD_DIR="/etc/systemd/system"
TARGET_SERVICE_FILE="${SYSTEMD_DIR}/${SERVICE_NAME}"

echo "Setting up ZCAM Values Exporter auto-start for GC-ARO-001-2..."
echo ""

# Check if service file exists
if [ ! -f "$SERVICE_FILE" ]; then
    echo "Error: Service file not found: $SERVICE_FILE"
    exit 1
fi

# Copy service file to systemd directory
echo "Copying service file to systemd directory..."
sudo cp "$SERVICE_FILE" "$TARGET_SERVICE_FILE"
echo "✓ Service file copied to $TARGET_SERVICE_FILE"

# Reload systemd daemon
echo "Reloading systemd daemon..."
sudo systemctl daemon-reload
echo "✓ Systemd daemon reloaded"

# Enable service to start on boot
echo "Enabling service to start on boot..."
sudo systemctl enable "$SERVICE_NAME"
echo "✓ Service enabled for auto-start on boot"

# Check service status
echo ""
echo "Checking service status..."
sudo systemctl status "$SERVICE_NAME" --no-pager -l || true

echo ""
echo "Setup completed successfully!"
echo ""
echo "To start the service now:"
echo "  sudo systemctl start $SERVICE_NAME"
echo ""
echo "To check service status:"
echo "  sudo systemctl status $SERVICE_NAME"
echo ""
echo "To view service logs:"
echo "  sudo journalctl -u $SERVICE_NAME -f"
echo ""

