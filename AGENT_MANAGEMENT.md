# Agent Management Guide

## Overview

This telemetry system now supports multiple agents running on different hosts. Each agent can be dynamically configured with a unique name and IP address.

## Quick Start

### Start a New Agent

```bash
# Basic usage
./start-agent.sh <agent_name> <agent_ip>

# Example: Start GC-ASB-001-1-agent on 100.64.0.166
./start-agent.sh GC-ASB-001-1-agent 100.64.0.166

# Example: Start original agent (backward compatibility)
./start-agent.sh
```

### List All Agents

```bash
./list-agents.sh
```

## File Structure

When you start a new agent, the following files are automatically generated:

```
agent-configs/
├── GC-ASB-001-1-agent.yml          # Agent configuration
├── GC-ARO-001-2-agent.yml          # Original agent config

promtail-GC-ASB-001-1-agent.yml     # Promtail configuration
docker-compose-GC-ASB-001-1-agent.yml  # Docker Compose file

zabbix/
├── agent2-GC-ASB-001-1-agent.conf  # Zabbix Agent configuration
└── scripts/                         # Monitoring scripts
```

## Agent Configuration

Each agent configuration file (`agent-configs/<agent_name>.yml`) contains:

- `agent_name`: Unique identifier for the agent
- `agent_ip`: IP address where the agent runs
- `server_ip`: Central server IP (100.64.0.113)
- Container names and network configuration
- Log files to monitor
- Configuration file paths

## Services

Each agent runs two main services:

### 1. Promtail (Log Collection)
- Collects logs from multiple sources
- Sends logs to central Loki server
- Monitors: mock_sicbo.log, server.log, tmux-client.log, sdp.log

### 2. Zabbix Agent (System Monitoring)
- Monitors system metrics
- Connects to central Zabbix server
- Provides system health data

## Management Commands

### Start Agent
```bash
./start-agent.sh <agent_name> <agent_ip>
```

### Stop Agent
```bash
docker compose -f docker-compose-<agent_name>.yml down
```

### View Logs
```bash
docker compose -f docker-compose-<agent_name>.yml logs -f
```

### List All Agents
```bash
./list-agents.sh
```

## Network Configuration

- **Server IP**: 100.64.0.113
- **Loki Port**: 3100
- **Zabbix Port**: 10051
- **Agent Port**: 10050 (mapped to host)

## Examples

### Create Multiple Agents

```bash
# Agent on host 1
./start-agent.sh GC-ASB-001-1-agent 100.64.0.166

# Agent on host 2
./start-agent.sh GC-ASB-001-2-agent 100.64.0.167

# Agent on host 3
./start-agent.sh GC-ASB-001-3-agent 100.64.0.168
```

### Check Agent Status

```bash
# List all agents and their status
./list-agents.sh

# Check specific agent containers
docker ps | grep GC-ASB-001-1-agent
```

## Backward Compatibility

The original agent (GC-ARO-001-2-agent) configuration is preserved. You can still start it using:

```bash
./start-agent.sh
# or
./start-agent.sh GC-ARO-001-2-agent 100.64.0.149
```

## Troubleshooting

### Docker Compose Issues
The script automatically detects and uses either `docker-compose` or `docker compose` based on what's available.

### Port Conflicts
Each agent uses port 10050. If you have multiple agents on the same host, you may need to modify the port mapping in the generated docker-compose file.

### Configuration Updates
Agent configurations are automatically generated and stored in the `agent-configs/` directory. You can manually edit these files if needed.

## Security Notes

- Ensure proper firewall rules for agent communication
- Use secure networks for agent-to-server communication
- Regularly update agent configurations as needed
