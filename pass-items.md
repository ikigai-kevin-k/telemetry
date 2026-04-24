# Pass Items: Agent -> New Server Connectivity (Generalized)

This document records what was successfully validated while connecting an agent node to a new server-side telemetry deployment, including the issues encountered, fixes applied, and repeatable steps.

It is written to be reusable for all agent nodes:
- `aro11`, `aro12`, `aro21`, `aro22`, `asb11`, `asb12`

---

## Scope

Validated path:
- Agent temperature metric push -> Server Pushgateway -> Prometheus-readable metric

Partially validated path:
- Agent service/container reachability to new server endpoints (Loki, Pushgateway, Zabbix trapper)

Not yet fully validated across all data types:
- ZCAM metrics scrape
- Full CPU/memory/network visibility in server Prometheus/Zabbix dashboards

---

## Environment Baseline

- New server-side endpoint (example in this rollout): `100.64.0.182`
- Legacy endpoint previously used by agents: `100.64.0.113`
- Key ports:
  - Loki: `3100`
  - Pushgateway: `9091`
  - Zabbix server (trapper): `10051`
  - Zabbix agent passive checks: `10050`
  - Prometheus: `9090`

---

## Problems Encountered and Fixes

### 1) Agent service still pushed to old server IP

**Symptom**
- `temperature-exporter-aro001-2.service` stayed active, but logs repeatedly showed:
  - `[warn] failed to push metric`
- Service logs still showed startup target as:
  - `http://100.64.0.113:9091`

**Root cause**
- Repo files were updated to new IP, but the deployed systemd unit under `/etc/systemd/system` still had the old environment value.

**Fix**
1. Copy updated unit file from repo into systemd path.
2. Reload systemd.
3. Restart exporter service.
4. Verify loaded unit value and runtime logs.

**Verification evidence**
- `systemctl cat` showed:
  - `Environment="PUSHGATEWAY_URL=http://100.64.0.182:9091"`
- Journal startup line changed to new server IP.
- Pushgateway returned the metric:
  - `system_temperature_celsius{instance="GC-ARO-001-2-agent",job="agent_temperature"} <value>`

---

### 2) Prometheus target checks showed multiple DOWN jobs

**Symptom**
- Server Prometheus targets had `down` for items like `telegraf-zcam`, `zcam-values`, etc.
- Some failures were DNS resolution for old container names or timeout/routing issues.

**Root cause**
- `prometheus.yml` targets were not fully aligned to the new server runtime/network topology.
- Some targets still referenced stale container DNS names or unreachable addresses.

**Fix direction**
- Update server-side `prometheus.yml` scrape targets to resolvable, reachable endpoints in the new deployment.
- Re-test `/api/v1/targets` until health is `up`.

---

## Executed Steps (Reusable Runbook)

Use this sequence for each agent (`aro11/aro12/aro21/aro22/asb11/asb12`), replacing placeholders.

### A) Update agent-side endpoints to new server

Update all relevant agent files:
- Promtail config: Loki URL -> `http://<NEW_SERVER_IP>:3100/loki/api/v1/push`
- Zabbix agent settings:
  - `ZBX_SERVER_HOST=<NEW_SERVER_IP>`
  - `ZBX_SERVER_ACTIVE=<NEW_SERVER_IP>`
  - `Server=<NEW_SERVER_IP>,...`
  - `ServerActive=<NEW_SERVER_IP>`
- Temperature/export scripts:
  - `PUSHGATEWAY_URL=http://<NEW_SERVER_IP>:9091`
- Agent metadata/config templates (`agent-configs/*.yml`) with `server_ip`

### B) Restart runtime components

```bash
docker compose -f docker-compose-<SITE>-agent.yml -f docker-compose-telegraf.yml -f docker-compose.yml up -d promtail zabbix-agent
```

For temperature exporter (systemd):

```bash
sudo cp temperature-exporter-<SITE>.service /etc/systemd/system/temperature-exporter-<SITE>.service
sudo systemctl daemon-reload
sudo systemctl restart temperature-exporter-<SITE>.service
```

### C) Connectivity checks from agent

```bash
curl -sS http://<NEW_SERVER_IP>:3100/ready
curl -sS http://<NEW_SERVER_IP>:9091/-/healthy
nc -zv <NEW_SERVER_IP> 10051
```

### D) Confirm service is using new endpoint

```bash
sudo systemctl cat temperature-exporter-<SITE>.service | grep PUSHGATEWAY_URL
sudo journalctl -u temperature-exporter-<SITE>.service -n 30 --no-pager
```

### E) Confirm metric arrived at server Pushgateway

```bash
curl -s http://<NEW_SERVER_IP>:9091/metrics | grep system_temperature_celsius
```

Expected:
- A line similar to:
  - `system_temperature_celsius{instance="<AGENT_INSTANCE>",job="agent_temperature"} <number>`

---

## PASS Items (Current)

- Agent temperature metric push path is working after systemd unit sync:
  - Agent exporter -> New server Pushgateway (`9091`) -> metric visible
- Agent can reach core server ports:
  - Pushgateway (`9091`) and Zabbix trapper (`10051`) reachable
- Promtail/Zabbix agent containers are running after endpoint updates

---

## TODO / Next Steps (Generalized)

1. **Server-side Prometheus target cleanup**
   - Remove/replace stale scrape targets (old container names, old IPs).
   - Ensure all expected jobs for each agent become `up`.

2. **Per-agent validation matrix**
   - For each agent (`aro11`, `aro12`, `aro21`, `aro22`, `asb11`, `asb12`), verify:
     - Loki log ingestion
     - Zabbix latest data freshness
     - Pushgateway temperature metric presence
     - Prometheus scrape status for zcam/telegraf/exporters

3. **ZCAM metrics path verification**
   - Confirm `zcam-values` and `telegraf-zcam` endpoints are reachable from the new server.
   - Validate key ZCAM metrics appear in Prometheus/Grafana.

4. **CPU / memory / network coverage check**
   - Confirm source of truth per metric (Prometheus exporter vs Zabbix items).
   - Validate dashboards use currently available metric names/labels.

5. **Standardize deployment procedure**
   - Add a common post-change script:
     - sync systemd units
     - reload/restart services
     - run health checks
     - print pass/fail summary per agent

6. **Improve observability for push failures**
   - Enhance temperature push script logs to include curl error details and status code.
   - Keep warning logs actionable (target URL, failure reason, retry count).

---

## Suggested Agent Checklist Template (Copy Per Site)

- [ ] Updated all `<NEW_SERVER_IP>` references in site-specific files
- [ ] Restarted promtail and zabbix-agent containers
- [ ] Synced and restarted temperature systemd service
- [ ] Agent -> Loki ready check passed
- [ ] Agent -> Pushgateway health check passed
- [ ] Agent -> Zabbix trapper check passed
- [ ] Temperature metric visible on Pushgateway
- [ ] Prometheus target state for site is `up`
- [ ] Grafana panels and/or Zabbix latest data confirmed fresh

