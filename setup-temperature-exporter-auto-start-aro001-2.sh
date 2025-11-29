#!/bin/bash
# Setup script to ensure Temperature Exporter starts automatically on boot for GC-ARO-001-2
# This script configures systemd service for temperature monitoring

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_NAME="temperature-exporter-aro001-2.service"
SERVICE_FILE="${SCRIPT_DIR}/${SERVICE_NAME}"
SYSTEMD_DIR="/etc/systemd/system"
TARGET_SERVICE_FILE="${SYSTEMD_DIR}/${SERVICE_NAME}"

echo "Setting up Temperature Exporter auto-start for GC-ARO-001-2..."
echo ""

# Check if service file exists
if [ ! -f "$SERVICE_FILE" ]; then
    echo "❌ Error: Service file not found: $SERVICE_FILE"
    exit 1
fi

# Make scripts executable
chmod +x "${SCRIPT_DIR}/start-temperature-exporter-aro001-2.sh" 2>/dev/null || true
chmod +x "${SCRIPT_DIR}/push_temperature_to_pushgateway_aro001_2.sh" 2>/dev/null || true
echo "✓ Scripts are executable"

# Copy service file to systemd directory
echo "[1/4] Copying service file to systemd directory..."
sudo cp "$SERVICE_FILE" "$TARGET_SERVICE_FILE"
echo "✓ Service file copied to $TARGET_SERVICE_FILE"

# Reload systemd daemon
echo "[2/4] Reloading systemd daemon..."
sudo systemctl daemon-reload
echo "✓ Systemd daemon reloaded"

# Enable service to start on boot
echo "[3/4] Enabling service to start on boot..."
sudo systemctl enable "$SERVICE_NAME"
echo "✓ Service enabled for auto-start on boot"

# Check if service is already running (from manual start)
if [ -f /tmp/temperature-exporter-aro001-2.pid ]; then
    OLD_PID=$(cat /tmp/temperature-exporter-aro001-2.pid)
    if ps -p "$OLD_PID" > /dev/null 2>&1; then
        echo "[4/4] Stopping manually started process (PID: $OLD_PID)..."
        kill "$OLD_PID" 2>/dev/null || true
        sleep 2
    fi
fi

# Start service via systemd
echo "[4/4] Starting service via systemd..."
sudo systemctl start "$SERVICE_NAME"
echo "✓ Service started"

# Check service status
echo ""
echo "Checking service status..."
sudo systemctl status "$SERVICE_NAME" --no-pager -l || true

echo ""
echo "✅ Setup completed successfully!"
echo ""
echo "Service will automatically start on boot."
echo ""
echo "Useful commands:"
echo "  Check status:  sudo systemctl status $SERVICE_NAME"
echo "  View logs:     sudo journalctl -u $SERVICE_NAME -f"
echo "  Restart:       sudo systemctl restart $SERVICE_NAME"
echo "  Stop:          sudo systemctl stop $SERVICE_NAME"
echo ""

