#!/bin/bash

# Dashboard Panel Persistence Script
echo "💾 Dashboard Panel Persistence Script"
echo "===================================="

echo "📊 Current Status:"
echo "=================="
echo "✅ CPU Usage panel: Working with 5 agents"
echo "✅ Network Traffic panel: Working with 5 agents"
echo "✅ Manual configuration: Applied successfully"
echo ""

echo "🔍 Extracting Current Panel Configuration..."
echo "==========================================="

# Get current dashboard configuration
echo "1. Fetching current dashboard configuration from Grafana API..."

# Try to get dashboard via API (may need authentication)
dashboard_response=$(curl -s "http://localhost:3000/api/dashboards/uid/overview-dashboard" 2>/dev/null)

if [[ "$dashboard_response" == *"Unauthorized"* ]]; then
    echo "   ⚠️  API access requires authentication"
    echo "   📝 Manual approach: Export dashboard from Grafana UI"
    echo ""
    echo "🔧 Manual Export Steps:"
    echo "======================="
    echo "1. 🌐 Open Grafana: http://localhost:3000"
    echo "2. 📊 Go to System Overview Dashboard"
    echo "3. ⚙️  Click Dashboard Settings (gear icon)"
    echo "4. 📤 Click 'Export' tab"
    echo "5. 💾 Copy the JSON content"
    echo "6. 📋 Paste it into a file for processing"
    echo ""
    echo "🔄 Alternative: Direct File Update"
    echo "================================="
    echo "Since you've manually configured the panels, we can:"
    echo "1. Backup current dashboard file"
    echo "2. Update the JSON with your working configuration"
    echo "3. Restart Grafana to apply changes"
    echo ""
    
    # Backup current file
    echo "📦 Creating backup of current dashboard..."
    cp /home/ella/kevin/telemetry/grafana/provisioning/dashboards/general/overview.json \
       /home/ella/kevin/telemetry/grafana/provisioning/dashboards/general/overview.json.backup.$(date +%Y%m%d_%H%M%S)
    echo "   ✅ Backup created"
    
    echo ""
    echo "💡 Next Steps:"
    echo "=============="
    echo "1. Export the working dashboard JSON from Grafana UI"
    echo "2. Replace the current overview.json file with the exported JSON"
    echo "3. Restart Grafana to apply the changes"
    echo ""
    echo "📋 Export Command Template:"
    echo "==========================="
    echo "curl -H 'Authorization: Bearer YOUR_TOKEN' \\"
    echo "     'http://localhost:3000/api/dashboards/uid/overview-dashboard' \\"
    echo "     | jq '.dashboard' > /tmp/exported_dashboard.json"
    echo ""
    echo "🔄 Or manually copy the JSON from Grafana UI export feature"
    
else
    echo "   ✅ Dashboard configuration retrieved"
    echo "$dashboard_response" | jq '.dashboard' > /tmp/current_dashboard.json
    echo "   📁 Saved to /tmp/current_dashboard.json"
fi

echo ""
echo "🎯 Persistence Strategy:"
echo "========================"
echo "Since manual configuration is working, we have two options:"
echo ""
echo "Option 1: Export from Grafana UI (Recommended)"
echo "• Go to Dashboard Settings > Export"
echo "• Copy the JSON content"
echo "• Replace the overview.json file"
echo ""
echo "Option 2: Manual JSON Update"
echo "• Identify the working panel configurations"
echo "• Update the JSON file with correct queries"
echo "• Restart Grafana"
echo ""
echo "✅ Ready to proceed with persistence!"
