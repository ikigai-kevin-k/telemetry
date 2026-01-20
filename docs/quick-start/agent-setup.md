# Agent Setup

## Quick Start

### Step 1: Start Agent Services

```bash
# Start agent with name and IP
./start-agent.sh GC-aro12-agent 100.64.0.149

# Or start specific agent
docker compose -f docker-compose-GC-aro12-agent.yml up -d
```

### Step 2: Verify Connection

The agent will automatically connect to the server:

- **Promtail** sends logs to server Loki (100.64.0.113:3100)
- **Zabbix Agent** sends metrics to server Zabbix (100.64.0.113:10051)

### Step 3: Check Agent Status

```bash
# List all agents
./list-agents.sh

# Check agent logs
docker compose -f docker-compose-GC-aro12-agent.yml logs -f
```

## Agent Configuration

Each agent requires:

- Unique agent name (e.g., `GC-aro12-agent`)
- Agent IP address
- Server IP address (for connection)

## File Structure

When you start a new agent, the following files are automatically generated:

```
agent-configs/
├── GC-aro12-agent.yml          # Agent configuration

promtail-GC-aro12-agent.yml     # Promtail configuration
docker-compose-GC-aro12-agent.yml  # Docker Compose file

zabbix/
├── agent2-GC-aro12-agent.conf  # Zabbix Agent configuration
└── scripts/                     # Monitoring scripts
```

## Next Steps

- Learn about [Agent Management](../guides/agent-management.md)
- Configure [Logging](../guides/logging-setup.md)




