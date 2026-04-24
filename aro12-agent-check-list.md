# ARO12 Agent-Side Check List (Step-by-Step Commands)

This checklist is for troubleshooting why server-side Prometheus cannot scrape:

- `100.64.0.149:9273` (telegraf-zcam)
- `100.64.0.149:9274` (zcam-values exporter)

Run the commands on **ARO12 agent host** (`100.64.0.149`) unless explicitly stated otherwise.

---

## 0) Confirm you are on the correct machine

```bash
hostname
hostname -I
tailscale ip -4
```

Expected: host is ARO12 agent and has IP `100.64.0.149` (or the current agent VPN IP).

---

## 1) Basic network sanity from agent side

```bash
ip -br addr
ip route
tailscale status --self
```

Check that network interface and routes are healthy.

---

## 2) Verify exporter processes/containers are running

### 2.1 If exporters are containerized

```bash
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
docker ps -a --format "table {{.Names}}\t{{.Status}}" | sed -n '1,50p'
```

Look for containers related to telegraf and zcam values exporter.

### 2.2 If exporters are system services

```bash
systemctl --type=service --state=running | rg -i "telegraf|zcam|exporter" || true
ps -ef | rg -i "telegraf|zcam|exporter" || true
```

---

## 3) Verify ports 9273/9274 are listening on agent

```bash
sudo ss -lntp | rg ":9273|:9274" || true
sudo lsof -iTCP -sTCP:LISTEN -P -n | rg ":9273|:9274" || true
```

Expected:

- Port `9273` is LISTEN
- Port `9274` is LISTEN
- Prefer bind address `0.0.0.0` (or agent VPN interface), not only `127.0.0.1`

---

## 4) Test exporters locally on agent

```bash
curl -sv --max-time 5 http://127.0.0.1:9273/metrics -o /tmp/aro12-9273.metrics
curl -sv --max-time 5 http://127.0.0.1:9274/metrics -o /tmp/aro12-9274.metrics
```

Quick content check:

```bash
sed -n '1,20p' /tmp/aro12-9273.metrics
sed -n '1,20p' /tmp/aro12-9274.metrics
```

If localhost works but remote scrape fails, issue is likely firewall/bind/routing.

---

## 5) Test exporters via agent VPN IP from agent itself

```bash
curl -sv --max-time 5 http://100.64.0.149:9273/metrics -o /dev/null
curl -sv --max-time 5 http://100.64.0.149:9274/metrics -o /dev/null
```

If this fails but localhost works, service may only bind to loopback.

---

## 6) Check firewall rules on agent

### UFW (if enabled)

```bash
sudo ufw status verbose
```

If needed:

```bash
sudo ufw allow 9273/tcp
sudo ufw allow 9274/tcp
sudo ufw reload
```

### iptables / nftables

```bash
sudo iptables -S | sed -n '1,200p'
sudo iptables -L -n -v | sed -n '1,200p'
sudo nft list ruleset | sed -n '1,240p'
```

---

## 7) Check exporter logs for errors

### Container logs

```bash
docker logs --tail 120 <telegraf-container-name>
docker logs --tail 120 <zcam-values-container-name>
```

### Service logs

```bash
journalctl -u telegraf -n 120 --no-pager
journalctl -u <zcam-values-service-name> -n 120 --no-pager
```

Look for bind errors, permission issues, crash loops, or upstream API failures.

---

## 8) Validate server -> agent connectivity (run on server `100.64.0.182`)

```bash
curl -sv --max-time 5 http://100.64.0.149:9273/metrics -o /dev/null
curl -sv --max-time 5 http://100.64.0.149:9274/metrics -o /dev/null
```

If server still times out:

- confirm Tailscale connectivity between nodes
- verify agent firewall allows traffic from server node
- verify exporters bind to non-loopback addresses

---

## 9) Prometheus-side verification (run on server)

```bash
curl -s http://127.0.0.1:9090/api/v1/targets | jq '.data.activeTargets[] | select(.labels.job|test("zcam")) | {job:.labels.job,address:.discoveredLabels.__address__,health,lastError}'
```

Expected:

- `telegraf-zcam` health = `up`
- `zcam-values` health = `up`
- `zcam-values-aro12` health = `up`

---

## 10) Optional quick rollback on server (if needed)

```bash
cd ~/telemetry
cp prometheus.yml.bak.<timestamp> prometheus.yml
docker compose up -d --force-recreate prometheus
```

---

## 11) Result template (fill after checks)

Use this template to record final status:

```text
[ARO12 CHECK RESULT]
- 9273 LISTEN: yes/no
- 9274 LISTEN: yes/no
- localhost 9273 metrics: pass/fail
- localhost 9274 metrics: pass/fail
- 100.64.0.149 9273 metrics: pass/fail
- 100.64.0.149 9274 metrics: pass/fail
- server->agent 9273 metrics: pass/fail
- server->agent 9274 metrics: pass/fail
- firewall blocked: yes/no
- action taken:
- final Prometheus zcam targets health:
```
