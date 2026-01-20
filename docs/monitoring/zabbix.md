# Zabbix Monitoring

## Overview

Zabbix is an enterprise-class open source monitoring solution for networks and applications. It monitors system resources and performance.

## Access

- **Web Interface**: http://localhost:8080
- **Server Port**: 10051
- **Container**: `kevin-telemetry-zabbix-server`

## Zabbix Metrics

Zabbix collects system metrics from agents:

- CPU, Memory, Disk usage
- Network interface statistics
- System load and processes
- Custom metrics via scripts

## Agent Configuration

Agents are configured in `zabbix/agent2-*.conf`:

```conf
Server=100.64.0.113
ServerActive=100.64.0.113
Hostname=GC-aro12-agent
```

## Monitoring Items

Common monitoring items:

- `system.cpu.util` - CPU utilization
- `system.mem.used` - Memory usage
- `vfs.fs.size[/,used]` - Disk usage
- `net.if.in[enp86s0]` - Network interface inbound
- `net.if.out[enp86s0]` - Network interface outbound

## Verify Service

```bash
# Check Zabbix server status
docker logs kevin-telemetry-zabbix-server

# Test agent connection
zabbix_agentd -t system.cpu.util
```




