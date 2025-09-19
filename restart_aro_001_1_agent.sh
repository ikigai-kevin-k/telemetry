#!/bin/bash

# Restart ARO-001-1 Agent with new Studio SDP log configuration
# This script applies the updated configuration for monitoring Studio SDP Roulette logs

echo "🔄 Restarting ARO-001-1 Agent with new Studio SDP log configuration..."

# Change to telemetry directory
cd /home/rnd/telemetry

# Stop the current agent
echo "⏹️  Stopping current ARO-001-1 agent..."
docker compose -f docker-compose-GC-ARO-001-1-agent.yml down

# Wait a moment for clean shutdown
sleep 3

# Restart Loki server with new retention configuration
echo "🔄 Restarting Loki server with updated retention policy..."
docker compose -f docker-compose.yml restart loki

# Wait for Loki to be ready
echo "⏳ Waiting for Loki server to be ready..."
sleep 10

# Start the agent with new configuration
echo "🚀 Starting ARO-001-1 agent with new configuration..."
docker compose -f docker-compose-GC-ARO-001-1-agent.yml up -d

# Wait for services to start
sleep 5

# Check container status
echo "📊 Checking container status..."
docker compose -f docker-compose-GC-ARO-001-1-agent.yml ps

# Show logs from Promtail to verify it's working
echo "📋 Promtail startup logs:"
docker compose -f docker-compose-GC-ARO-001-1-agent.yml logs --tail=20 promtail

echo ""
echo "✅ ARO-001-1 Agent restart completed!"
echo ""
echo "🔍 To test the configuration, run:"
echo "   python3 test_studio_sdp_logs.py"
echo ""
echo "📊 To monitor logs in real-time:"
echo "   docker compose -f docker-compose-GC-ARO-001-1-agent.yml logs -f promtail"
echo ""
echo "🌐 Access points:"
echo "   - Grafana: http://100.64.0.113:3000"
echo "   - Loki API: http://100.64.0.113:3100"
echo "   - Promtail metrics: http://100.64.0.167:9080"
