#!/bin/bash

# Script to update Zabbix datasource IP in Grafana configuration
# This addresses Docker DNS resolution issues

echo "🔧 Updating Zabbix datasource IP..."

# Get current Zabbix Web container IP
ZABBIX_IP=$(docker network inspect telemetry_monitoring | jq -r '.[0].Containers | to_entries[] | select(.value.Name == "kevin-telemetry-zabbix-web") | .value.IPv4Address' | cut -d'/' -f1)

if [ -z "$ZABBIX_IP" ]; then
    echo "❌ Could not find Zabbix Web container IP"
    exit 1
fi

echo "📍 Found Zabbix Web IP: $ZABBIX_IP"

# Update datasource configuration file
CONFIG_FILE="./grafana/provisioning/datasources/zabbix.yml"

if [ -f "$CONFIG_FILE" ]; then
    # Backup current config
    cp "$CONFIG_FILE" "$CONFIG_FILE.backup"
    
    # Update IP in config file
    sed -i "s|url: http://.*:8080|url: http://$ZABBIX_IP:8080|g" "$CONFIG_FILE"
    
    echo "✅ Updated datasource configuration"
    echo "🔄 Restarting Grafana to apply changes..."
    
    # Restart Grafana to reload configuration
    docker-compose restart grafana
    
    echo "✅ Grafana restarted successfully"
    echo "📝 New Zabbix datasource URL: http://$ZABBIX_IP:8080"
else
    echo "❌ Configuration file not found: $CONFIG_FILE"
    exit 1
fi
