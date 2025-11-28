#!/bin/bash
# Ensure ARO12 ZCAM Exporter auto-start on boot
# This script verifies and sets up auto-start configuration

set -e

SERVICE_NAME="telemetry-agent-GC-ARO-001-2.service"
SERVICE_FILE="telemetry-agent-GC-ARO-001-2.service"
SYSTEMD_DIR="/etc/systemd/system"
TARGET_SERVICE_FILE="${SYSTEMD_DIR}/${SERVICE_NAME}"
WORK_DIR="/home/rnd/telemetry"

echo "=========================================="
echo "ARO12 ZCAM Exporter Auto-Start Setup"
echo "=========================================="
echo ""

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then 
    echo "This script requires sudo privileges."
    echo "Please run: sudo $0"
    exit 1
fi

# Step 1: Verify docker-compose file exists
echo "[1/6] Verifying docker-compose file..."
if [ ! -f "${WORK_DIR}/docker-compose-GC-ARO-001-2-agent.yml" ]; then
    echo "❌ Error: docker-compose-GC-ARO-001-2-agent.yml not found in ${WORK_DIR}"
    exit 1
fi
echo "✓ docker-compose-GC-ARO-001-2-agent.yml found"

# Step 2: Verify exporter script exists
echo "[2/6] Verifying exporter script..."
if [ ! -f "${WORK_DIR}/scripts/zcam-values-exporter-aro12-agent.py" ]; then
    echo "❌ Error: zcam-values-exporter-aro12-agent.py not found"
    exit 1
fi
echo "✓ zcam-values-exporter-aro12-agent.py found"

# Step 3: Copy service file
echo "[3/6] Installing systemd service..."
if [ ! -f "${WORK_DIR}/${SERVICE_FILE}" ]; then
    echo "❌ Error: ${SERVICE_FILE} not found in ${WORK_DIR}"
    exit 1
fi

cp "${WORK_DIR}/${SERVICE_FILE}" "${TARGET_SERVICE_FILE}"
chmod 644 "${TARGET_SERVICE_FILE}"
echo "✓ Service file installed to ${TARGET_SERVICE_FILE}"

# Step 4: Reload systemd
echo "[4/6] Reloading systemd daemon..."
systemctl daemon-reload
echo "✓ Systemd daemon reloaded"

# Step 5: Enable service
echo "[5/6] Enabling service for auto-start on boot..."
systemctl enable "${SERVICE_NAME}"
echo "✓ Service enabled for auto-start"

# Step 6: Verify configuration
echo "[6/6] Verifying configuration..."
if systemctl is-enabled "${SERVICE_NAME}" > /dev/null 2>&1; then
    echo "✓ Service is enabled for auto-start"
else
    echo "❌ Warning: Service is not enabled"
fi

echo ""
echo "=========================================="
echo "Setup completed successfully!"
echo "=========================================="
echo ""
echo "Service Status:"
systemctl status "${SERVICE_NAME}" --no-pager -l | head -10 || true
echo ""
echo "To start the service now:"
echo "  sudo systemctl start ${SERVICE_NAME}"
echo ""
echo "To check service status:"
echo "  sudo systemctl status ${SERVICE_NAME}"
echo ""
echo "To view service logs:"
echo "  sudo journalctl -u ${SERVICE_NAME} -f"
echo ""
echo "To verify containers are running:"
echo "  docker ps | grep -E 'zcam-values-exporter|promtail|zabbix-agent'"
echo ""
echo "To verify metrics:"
echo "  curl http://localhost:9274/metrics | grep 'zcam.*aro12'"
echo ""

