# Agent-Side Checklist: Connect to a New Telemetry Server

This checklist covers what the **agent** host must do after **server-side** telemetry (for example Amazon Linux + Docker Compose) is running on a **new** machine, so logs and metrics keep flowing to the new stack.  
Background docs (may live on a specific Git branch): `.github/instructions/telemetry-amazon-linux-server-docker-up-settings.md`, `.github/instructions/telemetry-migration.md`, `.github/instructions/telemetry-architecture.md`.

---

## Automated verification log (already run on this host)

| Field | Value |
|-------|--------|
| **When** | 2026-04-24 (commands run on the agent host) |
| **Remote address read from config** | `100.64.0.113` (`promtail-GC-aro12-agent.yml`, `docker-compose-GC-ARO-001-2-agent.yml`, `zabbix/agent2-GC-aro12-agent.conf`) |
| **Phase 1 (connectivity)** | From this host, TCP/HTTP to `100.64.0.113` on `3100` / `9091` / `10051` / `3000` / `9090` **all failed** (`Connection refused` or unreachable). Check Tailscale, firewalls, whether central is up, or whether you already pointed configs at `<NEW_SERVER>` and should re-test with that address. |
| **Promtail logs** | Container is running, but logs show `error writing positions file` (missing/problem with `/tmp/positions/`). Fix so read offsets persist reliably. |
| **Local Prometheus (merged compose stack)** | `http://127.0.0.1:9090/-/healthy` OK; `telegraf-zcam` and `zcam-values` targets are **up**. |

**Legend**: `[x]` = verified on this host in that run; `[ ]` = failed or not automatable here (manual / server / browser).

---

## 0. Terms and assumptions

- [x] **New server address**: written as `<NEW_SERVER>` below. Replace with the real reachable IP or FQDN (for example the VPC IP from the runbook, or the Tailscale IP/DNS name if the new host joins Tailscale). (Doc-only; no machine check.)
- [x] **Legacy default**: many repo defaults still use `100.64.0.113` (old central); after migration they must become `<NEW_SERVER>` or ops-provided host. (Confirmed on-disk configs still use `100.64.0.113`.)
- [x] **Ports** (unchanged vs old architecture when only the host moves):  
  - Loki: `3100`  
  - Zabbix Server (active/passive): `10051`  
  - Pushgateway: `9091`  
  - Zabbix Agent passive (server → agent): `10050`  
  - Prometheus / Grafana (for checks or server config): `9090`, `3000`, etc.  

---

## 1. Network connectivity (before editing more config)

Run on the **agent** (substitute `<NEW_SERVER>`; the log below used `100.64.0.113` from config):

| Check | Suggested command | Expected | Verified |
|-------|-------------------|----------|----------|
| Loki ready | `curl -sS http://<NEW_SERVER>:3100/ready` | `ready` / HTTP 200 | [ ] |
| Pushgateway | `curl -sS http://<NEW_SERVER>:9091/-/healthy` | Healthy response | [ ] |
| Zabbix trapper | `nc -zv <NEW_SERVER> 10051` or `telnet` | TCP connects | [ ] |
| (Optional) Grafana / Prometheus | Browser or `curl` on `:3000`, `:9090` | As needed | [ ] |

**Note**: if the new server is only reachable inside a VPC and the agent is elsewhere, you need **Tailscale / VPN / subnet router** paths; changing YAML alone is not enough.

---

## 2. Promtail (logs → Loki)

| Step | Description | Verified |
|------|-------------|----------|
| 2.1 | Confirm which Promtail file this agent uses (e.g. `promtail-GC-aro12-agent.yml` or per-site `promtail-GC-ARO-*-agent.yml`). | [x] Compose uses `promtail-GC-aro12-agent.yml` |
| 2.2 | Set `clients.url` to `http://<NEW_SERVER>:3100/loki/api/v1/push`. | [x] A valid `clients.url` exists (currently `http://100.64.0.113:3100/...`); for a **new** server, update the URL and re-check this row as “migration done” |
| 2.3 | Reload or restart Promtail (e.g. `docker compose ... restart promtail`). | [x] Container `telemetry-promtail-GC-aro12-agent` is **Up** (no forced restart in that run) |
| 2.4 | In Grafana Explore (Loki) on the server, query by `job` / `instance` and confirm fresh logs. | [ ] Manual Grafana; remote Loki was unreachable from this host at verification time |

---

## 3. Zabbix Agent (host monitoring → Zabbix Server)

| Step | Description | Verified |
|------|-------------|----------|
| 3.1 | In Docker Compose for Zabbix Agent, set `ZBX_SERVER_HOST`, `ZBX_SERVER_ACTIVE` to `<NEW_SERVER>` (port usually stays `10051`). | [x] Set to `100.64.0.113` (reachability: see phase 1) |
| 3.2 | In mounted **agent2** config (e.g. `zabbix/agent2-GC-aro12-agent.conf`), align `Server=` / `ServerActive=` with Compose; keep `172.18.0.1` etc. if required locally. | [x] Matches compose; `Hostname=GC-aro12-agent` |
| 3.3 | Restart Zabbix Agent container. | [x] Container `telemetry-zabbix-agent-GC-aro12-agent` is **Up** |
| 3.4 | On Zabbix Server / cloud firewall, allow **server → agent TCP `10050`** for passive checks. | [ ] Confirm on server / cloud console |
| 3.5 | In Zabbix Web, host `ZBX_HOSTNAME` matches the agent and shows available. | [ ] Requires Zabbix Web login |

### 3A. New server = **fresh Zabbix database** (no old volume restore)

| Step | Description | Verified |
|------|-------------|----------|
| 3A.1 | Recreate the **Host** in Zabbix Web; name must **exactly** match the agent `ZBX_HOSTNAME`. | [ ] Not automatable locally |
| 3A.2 | Re-attach **Templates / Items / Triggers** to match the old environment. | [ ] Not automatable locally |
| 3A.3 | Confirm latest data and graphs update. | [ ] Not automatable locally |

---

## 4. Pushgateway (temperature and other push scripts)

| Step | Description | Verified |
|------|-------------|----------|
| 4.1 | Audit scripts using `PUSHGATEWAY_URL` or hard-coded `http://100.64.0.113:9091` (e.g. `push_temperature_to_pushgateway_aro001_2.sh`, other `push_temperature_*.sh`). | [x] Spot-checked `push_temperature_to_pushgateway_aro001_2.sh` default `http://100.64.0.113:9091` |
| 4.2 | Point to `http://<NEW_SERVER>:9091`, or inject via **env** / **systemd `Environment=`** to avoid scattered literals. | [ ] Still legacy default; update after cutover and re-verify |
| 4.3 | Restart related **systemd** units/timers if any. | [x] `temperature-exporter-aro001-2.service` is **active**; `push_temperature_to_pushgateway_aro001_2.sh` process present |
| 4.4 | On the new server’s Prometheus or Grafana, confirm metrics by job/instance. | [ ] Remote PG unreachable in that run; optional: hit local `http://127.0.0.1:9091` if that is your test PG |

---

## 5. Prometheus / Telegraf / exporters (metric path)

Common pattern in this repo: **Telegraf** uses `outputs.prometheus_client` on **`:9273`**, scraped by **Prometheus on the same host** via `prometheus.yml`.

To use **Prometheus on the new server** as the central scraper:

| Step | Description | Verified |
|------|-------------|----------|
| 5.1 | **Server-side**: add/update `prometheus.yml` scrape jobs to targets reachable **from** the new Prometheus (e.g. `agent-tailscale-ip:9273`, `:9274`). | [ ] Server-side change; not verified here |
| 5.2 | **Network**: new Prometheus must reach agent exporter ports; open agent firewall if needed. | [ ] Requires joint connectivity test |
| 5.3 | **Alternative**: if reverse scrape is hard, consider **remote_write** from Telegraf (must match server Prometheus config). | [ ] N/A if not adopted |

**Local merged stack (reference only)**: `127.0.0.1:9090` Prometheus healthy; `telegraf-zcam` and `zcam-values` **up**. That is **local** scraping on the agent box, not completion of “central Prometheus on new server.”

**Reminder**: changing Promtail / Zabbix / Pushgateway to a new IP does **not** by itself make a remote Prometheus scrape local Telegraf unless 5.1–5.2 (or remote_write) are done.

---

## 6. Other files that may still reference the old server

Search the repo for `100.64.0.113` and decide per site whether to switch to `<NEW_SERVER>`:

- [ ] Defaults in `start-agent.sh`, `generate-agent-configs.sh` (`SERVER_IP`) — not fully audited file-by-file in that run  
- [ ] `server_ip` in `agent-configs/*.yml`  
- [x] Confirmed `docker-compose-GC-ARO-001-2-agent.yml` still contains `100.64.0.113` (consistent with “not yet cut over”)  
- [ ] Test/verify scripts (`ZABBIX_URL`, etc.): if they call Zabbix API from your laptop, point at new server `:8080`  

---

## 7. Post-change verification summary

| Item | How to confirm | Verified |
|------|----------------|----------|
| Loki | Grafana Explore shows this agent’s log streams | [ ] |
| Zabbix | Host green, Latest data updates | [ ] |
| Pushgateway | Prometheus shows fresh timestamps for temperature metrics | [ ] Remote PG unreachable; local push process was running |
| (Optional) Central Prometheus | `/targets` shows agent jobs **UP** | [ ] Means Prometheus **on the new server** |
| Containers | `docker compose ps` stable; check promtail/zabbix-agent logs | [x] Core services **Up**; `zabbix-web` **Exited** (expected for this local stack); **fix Promtail positions path errors** |

---

## 8. Rollback

If the new server is temporarily unusable:

- Revert settings to a **reachable** old central (if it still exists) and restart services; or  
- Follow `telemetry-migration.md`: fix connectivity and environment, then cut over again.

---

## 9. In-repo references

- `.github/instructions/telemetry-amazon-linux-server-docker-up-settings.md` — Amazon Linux bring-up issues and example service URLs  
- `.github/instructions/telemetry-migration.md` — migration scope, no old volumes, verification list  
- `.github/instructions/telemetry-architecture.md` — agent vs server services and data flow  

(If those files only exist on a branch, `git fetch` and check out the branch that contains the commits.)

---

**Document version**: aligned with “new server Docker Compose + agent connectivity.” Actual `<NEW_SERVER>` and firewall rules are defined by operations.

**Chinese version**: [`agent-side-connect-new-server-side-checklist.md`](./agent-side-connect-new-server-side-checklist.md)
