#!/bin/bash

# Network Monitor Stop Script
# This script stops the network monitoring service

echo "Stopping Network Interface Monitor..."

# Check if PID file exists
if [ -f /tmp/network_monitor.pid ]; then
    NETWORK_MONITOR_PID=$(cat /tmp/network_monitor.pid)
    
    # Check if process is still running
    if ps -p $NETWORK_MONITOR_PID > /dev/null 2>&1; then
        echo "Stopping network monitor (PID: $NETWORK_MONITOR_PID)..."
        kill $NETWORK_MONITOR_PID
        
        # Wait a moment for graceful shutdown
        sleep 2
        
        # Force kill if still running
        if ps -p $NETWORK_MONITOR_PID > /dev/null 2>&1; then
            echo "Force stopping network monitor..."
            kill -9 $NETWORK_MONITOR_PID
        fi
        
        echo "Network monitor stopped successfully!"
    else
        echo "Network monitor process not found (PID: $NETWORK_MONITOR_PID)"
    fi
    
    # Remove PID file
    rm -f /tmp/network_monitor.pid
else
    echo "PID file not found. Trying to find and stop network monitor process..."
    
    # Try to find and kill the process by name
    pkill -f "network_monitor.py"
    
    if [ $? -eq 0 ]; then
        echo "Network monitor stopped successfully!"
    else
        echo "No network monitor process found."
    fi
fi
