#!/bin/bash

# Network Monitor Startup Script
# This script starts the network monitoring service

echo "Starting Network Interface Monitor..."

# Create log directory if it doesn't exist
mkdir -p /home/rnd/telemetry/logs
touch /home/rnd/telemetry/logs/network_stats.log

# Start the network monitor in background
echo "Starting network_monitor.py..."
python3 /home/rnd/telemetry/network_monitor.py &

# Get the PID
NETWORK_MONITOR_PID=$!
echo "Network Monitor PID: $NETWORK_MONITOR_PID"

# Save PID to file for easy stopping
echo $NETWORK_MONITOR_PID > /tmp/network_monitor.pid

echo "Network monitoring started successfully!"
echo "Log file: /home/rnd/telemetry/logs/network_stats.log"
echo "To stop: kill $NETWORK_MONITOR_PID"
echo "Or run: ./stop-network-monitor.sh"
