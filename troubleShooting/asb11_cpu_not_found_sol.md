## ASB11 CPU usage not shown in Grafana – Diagnosis and Fix

### Context
- Environment: Zabbix Server (Docker or host) + agents on remote hosts.
- Symptom: Grafana “CPU Usage - All Agents” panel showed no data for ASB11 (host `GC-ASB-001-1`), while other agents were fine.

### Quick Summary
ASB11’s Zabbix Agent 2 was either absent or misconfigured. The server could ping the host, but passive checks failed due to agent configuration and a conflicting listener. After installing/configuring `zabbix-agent2`, freeing TCP/10050, aligning hostname and server allowlist, and validating from the Zabbix Server with `zabbix_get`, Grafana started receiving CPU metrics and the panel populated.

### Symptoms Observed
- Zabbix Web UI showed host “Unavailable” or agent error for ASB11.
- From Zabbix Server, `zabbix_get` returned:
  - `ZBX_TCP_READ() failed: [104] Connection reset by peer`
  - Hint: “Check access restrictions in Zabbix agent configuration”.
- Later, agent-side logs showed: `cannot start server listener: ... bind: address already in use` (port 10050 in use by another process).
- Hostname reported in agent logs was `Zabbix server` (wrong) before being corrected to `GC-ASB-001-1`.

### Root Causes
1) Zabbix Agent 2 not properly configured on ASB11.
2) TCP/10050 already occupied by another agent process or container.
3) Hostname mismatch and/or missing allowlist for the Zabbix Server IP in agent config.
4) Optional: Shell quoting issues during configuration when using fish (heredoc not supported), preventing config file creation.

### Resolution Steps

#### A. Server-side connectivity test (from Zabbix Server)
If Zabbix Server runs in Docker, exec into the right container name; otherwise run directly on the host where zabbix-server runs.

```bash
# Docker: find the actual server container name, then test
docker ps --format '{{.Names}}' | grep -i zabbix
docker exec -it <zabbix-server-container> bash -lc \
  "zabbix_get -s 100.64.0.166 -p 10050 -k agent.ping; \
   zabbix_get -s 100.64.0.166 -p 10050 -k system.hostname"

# Or on a host with zabbix-get installed
zabbix_get -s 100.64.0.166 -p 10050 -k agent.ping
zabbix_get -s 100.64.0.166 -p 10050 -k system.hostname
```

Expected (after fix):
- `agent.ping` prints `1`
- `system.hostname` prints `GC-ASB-001-1`

#### B. Agent-side installation and minimal configuration (ASB11)

Install Zabbix Agent 2 and create a minimal config allowing the server IP (example: `100.64.0.113`).

```bash
sudo apt update && sudo apt install -y zabbix-agent2

# If using fish shell, use one of the following to create the config file:
# 1) invoke bash with heredoc
sudo bash -lc 'cat >/etc/zabbix/zabbix_agent2.conf << "CFG"
Server=100.64.0.113
HostnameItem=system.hostname
Include=/etc/zabbix/zabbix_agent2.d/*.conf
CFG'

# 2) or fish-friendly printf | tee
printf '%s\n' \
'Server=100.64.0.113' \
'HostnameItem=system.hostname' \
'Include=/etc/zabbix/zabbix_agent2.d/*.conf' \
| sudo tee /etc/zabbix/zabbix_agent2.conf >/dev/null

# Allow Zabbix passive port
sudo ufw allow 10050/tcp || true
```

Ensure no conflicting listeners on TCP/10050:

```bash
sudo ss -lntp | grep 10050 || true
sudo lsof -iTCP:10050 -sTCP:LISTEN -Pn || true

# If another agent instance is listening, stop/disable it
sudo systemctl stop zabbix-agent || true
sudo systemctl disable zabbix-agent || true
```

Start Agent 2 and verify logs:

```bash
sudo systemctl enable --now zabbix-agent2
sudo systemctl status zabbix-agent2 --no-pager
sudo journalctl -u zabbix-agent2 -n 100 --no-pager
```

Healthy signs:
- No “address already in use”.
- Log shows: `Zabbix Agent2 hostname: [GC-ASB-001-1]`.

#### C. Zabbix Web UI alignment
- Configuration → Hosts → `GC-ASB-001-1-agent` → Interfaces
  - Use IP with the correct address (ASB11 IP), Port `10050`.
  - Monitored by: `Server` (not Proxy).
- Encryption: set to “No encryption” unless you have PSK/Cert consistently configured on both sides.
- Templates: ensure `Linux by Zabbix agent` (or your standard agent template) is linked.
- Click “Check now” and watch Availability turn green.

#### D. Final server-side verification

```bash
zabbix_get -s 100.64.0.166 -p 10050 -k agent.ping   # expect 1
zabbix_get -s 100.64.0.166 -p 10050 -k system.hostname  # expect GC-ASB-001-1
```

When the above succeeds, Zabbix will ingest new data points; Grafana panels that query those items (CPU usage) will populate shortly after.

### Notes on Common Pitfalls
- Fish shell does not support bash heredoc redirection (`<<`). Use `sudo bash -lc 'cat <<EOF'` or `printf | tee` instead.
- If you use Active checks, add `ServerActive=<zabbix_server_ip>` and ensure the host’s `Host name` in Zabbix matches the agent-reported hostname (`system.hostname`) or set `Hostname` explicitly. For initial troubleshooting, passive checks are simpler.
- If TLS is enabled on either side, both must match (PSK identity/secret or certificates). For first diagnostics, keep it unencrypted.

### Outcome
After applying the steps above, `zabbix_get` returned:

```
1
GC-ASB-001-1
```

Grafana’s “CPU Usage - All Agents” panel began showing ASB11 data as expected.

### Prevention Checklist
- Agent service (`zabbix-agent2`) enabled and running; no duplicate listeners on 10050.
- `Server=<zabbix_server_ip>` present; `ServerActive=` as needed.
- Hostname alignment: use `HostnameItem=system.hostname` or ensure static `Hostname` matches Zabbix host.
- Firewall allows TCP/10050 from the server.
- Zabbix host interface uses the correct IP/port and is monitored by the correct server/proxy.
- Optional: Consistent TLS configuration across agent and server.


