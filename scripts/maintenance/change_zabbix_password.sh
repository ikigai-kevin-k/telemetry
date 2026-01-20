#!/bin/bash

# Script to change Zabbix Admin password to 'admin' (same as Grafana)
# This script connects to the MySQL database and updates the password

echo "Changing Zabbix Admin password to 'admin'..."

# Wait for MySQL to be ready
echo "Waiting for MySQL to be ready..."
until docker exec kevin-telemetry-zabbix-db mysqladmin ping -h localhost --silent; do
    echo "Waiting for MySQL..."
    sleep 2
done

echo "MySQL is ready. Updating Zabbix password..."

# Execute SQL to change password
docker exec kevin-telemetry-zabbix-db mysql -u zabbix -pzabbix_pwd zabbix -e "
UPDATE users 
SET passwd = MD5('admin'), username = 'admin' 
WHERE username = 'Admin';
"

if [ $? -eq 0 ]; then
    echo "✅ Zabbix password successfully changed to 'admin'"
    echo "✅ Username changed to 'admin' (lowercase)"
    echo ""
    echo "New Zabbix login credentials:"
    echo "  Username: admin"
    echo "  Password: admin"
    echo "  URL: http://localhost:8080"
else
    echo "❌ Failed to change Zabbix password"
    exit 1
fi
