#!/bin/bash

# Script to help fix agent connection issues

echo "=== Zabbix Agent Connection Diagnostic ==="
echo ""

echo "1. Checking network connectivity..."
ping -c 2 100.64.0.149 > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✓ Network connectivity to 100.64.0.149 is OK"
else
    echo "✗ Network connectivity to 100.64.0.149 failed"
    exit 1
fi

echo ""
echo "2. Checking Zabbix server status..."
docker ps | grep zabbix-server > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✓ Zabbix server is running"
else
    echo "✗ Zabbix server is not running"
    exit 1
fi

echo ""
echo "3. Checking Zabbix server logs for connection attempts..."
echo "Recent connection attempts to 100.64.0.149:"
docker logs kevin-telemetry-zabbix-server --tail 50 | grep "100.64.0.149" | tail -5

echo ""
echo "4. Checking if agent port is accessible..."
timeout 5 bash -c "</dev/tcp/100.64.0.149/10050" 2>/dev/null
if [ $? -eq 0 ]; then
    echo "✓ Port 10050 on 100.64.0.149 is accessible"
else
    echo "✗ Port 10050 on 100.64.0.149 is not accessible"
    echo "  This is normal for Zabbix agent as it only accepts connections from server"
fi

echo ""
echo "5. Recommended actions for remote agent:"
echo "   On the remote machine (100.64.0.149), run these commands:"
echo ""
echo "   # Check current agent configuration"
echo "   docker exec kevin-telemetry-zabbix-agent cat /etc/zabbix/zabbix_agent2.conf | grep -E '(Server|Hostname)'"
echo ""
echo "   # Update agent configuration if needed"
echo "   docker exec -it kevin-telemetry-zabbix-agent sh -c 'sed -i \"s/Server=.*/Server=100.64.0.113/\" /etc/zabbix/zabbix_agent2.conf'"
echo "   docker exec -it kevin-telemetry-zabbix-agent sh -c 'sed -i \"s/ServerActive=.*/ServerActive=100.64.0.113/\" /etc/zabbix/zabbix_agent2.conf'"
echo "   docker exec -it kevin-telemetry-zabbix-agent sh -c 'sed -i \"s/Hostname=.*/Hostname=GC-aro12-agent/\" /etc/zabbix/zabbix_agent2.conf'"
echo ""
echo "   # Restart agent"
echo "   docker restart kevin-telemetry-zabbix-agent"
echo ""
echo "   # Check agent logs"
echo "   docker logs kevin-telemetry-zabbix-agent --tail 20"

echo ""
echo "6. After fixing the agent configuration, wait 2-3 minutes and check:"
echo "   - Zabbix web interface: Monitoring > Hosts"
echo "   - The Availability column should show green ZBX instead of grey"
echo "   - Check Monitoring > Latest data for data collection"

echo ""
echo "=== Diagnostic Complete ==="
