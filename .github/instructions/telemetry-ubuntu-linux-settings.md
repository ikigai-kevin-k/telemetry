# Ubuntu Linux Server-Side Docker Compose: Issues, Fixes, and Final Runbook

This document describes common problems when starting the **server-side** telemetry stack from the repository root `docker-compose.yml` on a fresh **Ubuntu** host (replacing an Amazon Linux or other layout), the fixes that apply, and a concise end-to-end procedure.

The stack includes: Prometheus, Alertmanager, Pushgateway, Loki, Grafana, Zabbix (MySQL + server + web), disk-usage exporter, webhook service, and eBPF exporter (built locally).

---

## Prerequisites

- Ubuntu with Docker Engine and the **Docker Compose v2** plugin (`docker compose`, not legacy `docker-compose`).
- Network access to pull images and reach any scrape targets defined in `prometheus.yml`.
- If agents use Tailscale (or similar), set the host’s stable VPN IP (example: `100.64.0.182`) and ensure agents can route to it.

Install Docker on Ubuntu (official packages are preferred; adjust for your release):

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl
# Follow Docker’s official “Install Docker Engine on Ubuntu” steps, then:
sudo apt-get install -y docker-compose-plugin
docker compose version
```

Add your user to the `docker` group if you run compose without `sudo`:

```bash
sudo usermod -aG docker "$USER"
# log out and back in, then verify:
docker run --rm hello-world
```

---

## Issue 1 — Missing `byteplus-credentials.env` (compose fails immediately)

### Symptom

```text
env file /path/to/telemetry/byteplus-credentials.env not found: stat ... no such file or directory
```

Compose exits before creating containers.

### Root cause

`docker-compose.yml` mounts Grafana with:

```yaml
env_file:
  - ./byteplus-credentials.env
```

Docker Compose **requires that file to exist** on the host, even if all values inside are empty.

### Fix

Create the real file from the tracked template (the template is **`byteplus-credentials.env.example`**; the real file **`byteplus-credentials.env`** is gitignored):

```bash
cd /path/to/telemetry
cp byteplus-credentials.env.example byteplus-credentials.env
chmod 600 byteplus-credentials.env
```

Edit `byteplus-credentials.env` and set `BYTEPLUS_ACCESS_KEY` and `BYTEPLUS_SECRET_KEY` if you use the BytePlus / VMP Grafana datasource. Leave them blank if you do not use that integration.

---

## Issue 2 — Compose warnings: `BYTEPLUS_ACCESS_KEY`, `BYTEPLUS_SECRET_KEY`, `SLACK_WEBHOOK_URL` not set

### Symptom

```text
WARN ... The "BYTEPLUS_ACCESS_KEY" variable is not set. Defaulting to a blank string.
WARN ... The "BYTEPLUS_SECRET_KEY" variable is not set. Defaulting to a blank string.
WARN ... The "SLACK_WEBHOOK_URL" variable is not set. Defaulting to a blank string.
```

### Root cause

`docker-compose.yml` uses **Compose variable interpolation** (e.g. `${BYTEPLUS_ACCESS_KEY}`) for some `environment:` entries. Interpolation reads the **Compose project environment**: project-root **`.env`**, the shell, or `export`. It does **not** read `byteplus-credentials.env` (that file is only passed into the Grafana container as `env_file`).

### Fix (pick one)

**A)** Export before `docker compose` (good for Slack):

```bash
export SLACK_WEBHOOK_URL='https://hooks.slack.com/services/...'   # if used
export BYTEPLUS_ACCESS_KEY='...'
export BYTEPLUS_SECRET_KEY='...'
```

**B)** Create a project-root `.env` (separate from `byteplus-credentials.env`) used by Compose for interpolation:

```bash
cat > .env << 'EOF'
BYTEPLUS_ACCESS_KEY=
BYTEPLUS_SECRET_KEY=
SLACK_WEBHOOK_URL=
SERVER_IP=100.64.0.182
EOF
```

Grafana still loads secrets from `byteplus-credentials.env` via `env_file`; keeping both in sync is optional but avoids confusion.

---

## Issue 3 — Obsolete `version` key in `docker-compose.yml`

### Symptom

```text
the attribute `version` is obsolete, it will be ignored
```

### Root cause

Compose specification v2 no longer requires a top-level `version:` field.

### Fix

Safe to ignore. Optionally remove the `version:` line from `docker-compose.yml` in a follow-up change to silence the warning.

---

## Issue 4 — Prometheus / Alertmanager external URLs

### Symptom

Links inside Prometheus or Alertmanager UIs point at the wrong host or IP (e.g. old GE/TPE addresses).

### Root cause

`prometheus` and `alertmanager` services use `--web.external-url=http://${SERVER_IP:-100.64.0.113}:...`.

### Fix

Set `SERVER_IP` to this host’s reachable address (often the Tailscale IP) **before** `up` or `restart`:

```bash
export SERVER_IP=100.64.0.182
docker compose up -d
```

Or add `SERVER_IP=...` to the project-root `.env` used by Compose (see Issue 2).

---

## Issue 5 — `prometheus.yml` scrape targets still point at old infrastructure

### Symptom

Prometheus **Targets** page shows many jobs as down after migration.

### Root cause

Several `static_configs` in `prometheus.yml` use **hard-coded IPs or hostnames** (e.g. studio, ZCAM exporters, disk-usage host, agent exporters). They are independent of `SERVER_IP`.

### Fix

Edit `prometheus.yml` (and related rule files if needed) so each `targets:` entry matches the **current** network layout on Ubuntu. This is environment-specific and must be done per deployment.

---

## Issue 6 — eBPF exporter on Ubuntu

### Symptom

`ebpf-exporter` fails to build or start (kernel headers, BTF, or `/sys/kernel/debug`).

### Root cause

The service is `privileged` and mounts debugfs and `/lib/modules`. Build/runtime expectations can differ between kernels and distros.

### Fix

Ensure the host kernel matches what the Dockerfile expects; install `linux-headers-$(uname -r)` on the host if builds fail. If eBPF is not required on this server, coordinate with your team to disable or omit that service (project-specific).

---

## Final execution steps (clean runbook)

Run from the repository root (e.g. `~/telemetry`), on the `server` branch if your workflow uses it.

```bash
cd /path/to/telemetry

# 1) Credentials file required by Compose for Grafana
cp -n byteplus-credentials.env.example byteplus-credentials.env 2>/dev/null || true
test -f byteplus-credentials.env || cp byteplus-credentials.env.example byteplus-credentials.env
chmod 600 byteplus-credentials.env
# Edit byteplus-credentials.env if BytePlus keys are required

# 2) Optional: Compose interpolation (silences WARNs, Alertmanager Slack)
# Create or edit .env in repo root:
#   BYTEPLUS_ACCESS_KEY=...
#   BYTEPLUS_SECRET_KEY=...
#   SLACK_WEBHOOK_URL=...
#   SERVER_IP=100.64.0.182

export SERVER_IP=100.64.0.182   # if not using .env

# 3) Start everything (build local images: webhook, ebpf-exporter)
docker compose up -d --build

# 4) Verify
docker compose ps
docker compose logs -f --tail 50 grafana
```

### Service URLs (replace with your `SERVER_IP`)

| Service        | URL / endpoint                          |
|----------------|-----------------------------------------|
| Grafana        | `http://<SERVER_IP>:3000` (default admin/admin — change in production) |
| Prometheus     | `http://<SERVER_IP>:9090`               |
| Alertmanager   | `http://<SERVER_IP>:9093`               |
| Pushgateway    | `http://<SERVER_IP>:9091`               |
| Loki           | `http://<SERVER_IP>:3100`               |
| Zabbix Web     | `http://<SERVER_IP>:8080`               |
| Zabbix Server  | `<SERVER_IP>:10051`                     |

### Stop / reset (destructive: removes named volumes)

```bash
docker compose down -v
```

---

## Agent-side reminder

If the central server IP changed (e.g. to `100.64.0.182`), update **each agent**: Promtail remote Loki URL, Zabbix agent `Server` / `ServerActive`, and any scripts or compose overrides that still reference the old server IP.

---

## Related files

| File | Purpose |
|------|---------|
| `byteplus-credentials.env.example` | Template; copy to `byteplus-credentials.env` |
| `byteplus-credentials.env` | Local secrets for Grafana (gitignored) |
| `.env` | Optional Compose interpolation variables (often gitignored — do not commit secrets) |
| `docker-compose.yml` | Server-side stack definition |
| `scripts/setup/setup-byteplus-credentials.sh` | Interactive helper to create `byteplus-credentials.env` |

For Amazon Linux–specific notes (different package manager and Compose install path), see `telemetry-amazon-linux-server-docker-up-settings.md`.
