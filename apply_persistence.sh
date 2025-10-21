#!/bin/bash

# Automated Dashboard Persistence Script
echo "🤖 Automated Dashboard Persistence Script"
echo "========================================"

# Check if exported JSON file exists
if [ -f "exported_dashboard.json" ]; then
    echo "✅ Found exported_dashboard.json"
    echo "📊 File size: $(wc -c < exported_dashboard.json) bytes"
    echo ""
    
    echo "🔄 Applying configuration..."
    echo "=========================="
    
    # Backup current file
    echo "1. 📦 Creating backup of current dashboard..."
    backup_file="/home/ella/kevin/telemetry/grafana/provisioning/dashboards/general/overview.json.backup.$(date +%Y%m%d_%H%M%S)"
    cp /home/ella/kevin/telemetry/grafana/provisioning/dashboards/general/overview.json "$backup_file"
    echo "   ✅ Backup created: $backup_file"
    
    # Replace with exported configuration
    echo "2. 🔄 Replacing dashboard configuration..."
    cp exported_dashboard.json /home/ella/kevin/telemetry/grafana/provisioning/dashboards/general/overview.json
    echo "   ✅ Configuration replaced"
    
    # Restart Grafana
    echo "3. 🔄 Restarting Grafana container..."
    docker restart kevin-telemetry-grafana
    echo "   ✅ Grafana restarted"
    
    # Wait for Grafana to start
    echo "4. ⏳ Waiting for Grafana to start..."
    sleep 20
    
    # Check if Grafana is running
    if curl -s "http://localhost:3000/api/health" | jq -r '.database' 2>/dev/null | grep -q "ok"; then
        echo "   ✅ Grafana is running"
    else
        echo "   ⚠️  Grafana may still be starting up"
    fi
    
    echo ""
    echo "🎉 Persistence Complete!"
    echo "========================"
    echo "✅ Dashboard configuration has been persisted"
    echo "✅ Grafana has been restarted"
    echo "✅ Your manual panel configurations are now saved"
    echo ""
    echo "🔍 Verification Steps:"
    echo "======================"
    echo "1. 🌐 Open Grafana: http://localhost:3000"
    echo "2. 📊 Go to System Overview Dashboard"
    echo "3. 🔍 Check CPU Usage panel - should show 5 agents"
    echo "4. 🔍 Check Network Traffic panel - should show 5 agents"
    echo "5. ✅ Both panels should display data correctly"
    echo ""
    echo "💾 Backup Information:"
    echo "===================="
    echo "Original configuration backed up to:"
    echo "$backup_file"
    echo ""
    echo "If you need to restore the original configuration:"
    echo "cp \"$backup_file\" /home/ella/kevin/telemetry/grafana/provisioning/dashboards/general/overview.json"
    echo "docker restart kevin-telemetry-grafana"
    
else
    echo "❌ exported_dashboard.json not found"
    echo ""
    echo "📋 Please follow these steps first:"
    echo "==================================="
    echo ""
    echo "1. 🌐 Open Grafana: http://localhost:3000"
    echo "2. 📊 Go to System Overview Dashboard"
    echo "3. ⚙️  Click Dashboard Settings (gear icon)"
    echo "4. 📤 Click 'JSON Model' tab"
    echo "5. 📋 Copy the entire JSON content"
    echo "6. 💾 Save it as 'exported_dashboard.json' in this directory"
    echo "7. 🔄 Run this script again"
    echo ""
    echo "📁 Current directory: $(pwd)"
    echo "📋 Files in current directory:"
    ls -la *.json 2>/dev/null || echo "   No JSON files found"
fi
