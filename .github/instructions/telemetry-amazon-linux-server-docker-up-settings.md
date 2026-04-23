# Amazon Linux Server-Side Docker Startup: Issues, Fixes, and Final Runbook

## Background and Error Summary

This document summarizes all issues encountered while bringing up the server-side telemetry Docker stack on an Amazon Linux host, along with the exact fixes applied and the final working startup sequence.

Target stack includes:
- Prometheus
- Alertmanager
- Pushgateway
- Loki
- Grafana
- Zabbix DB / Server / Web
- (Optional) eBPF exporter and webhook service

## Issues Encountered and Resolutions

### 1) Docker Compose not available

**Symptom**
- `dnf install -y docker compose` failed with:
  - `No match for argument: compose`
- `docker compose version` failed with:
  - `docker: 'compose' is not a docker command`

**Root cause**
- Amazon Linux repositories did not provide a `compose` package in this environment.
- Compose plugin was not installed yet.

**Fix**
- Install Docker Compose v2 plugin manually:

```bash
mkdir -p ~/.docker/cli-plugins
curl -SL https://github.com/docker/compose/releases/download/v2.27.0/docker-compose-linux-x86_64 \
  -o ~/.docker/cli-plugins/docker-compose
chmod +x ~/.docker/cli-plugins/docker-compose
docker compose version
```

---

### 2) Docker daemon not running

**Symptom**
- `Cannot connect to the Docker daemon at unix:///var/run/docker.sock`
- `systemctl is-active docker` returned `inactive`.

**Root cause**
- Docker service was installed but not started/enabled.

**Fix**

```bash
sudo systemctl enable --now docker
sudo systemctl status docker --no-pager -n 20
```

---

### 3) Compose env interpolation warnings

**Symptom**
- Compose warned that variables were unset:
  - `BYTEPLUS_ACCESS_KEY`
  - `BYTEPLUS_SECRET_KEY`
  - `SLACK_WEBHOOK_URL`

**Root cause**
- `.env` file did not exist in project root, so `${...}` interpolation in `docker-compose.yml` used empty defaults.

**Fix**
- Create `.env`:

```bash
cat > .env << 'EOF'
BYTEPLUS_ACCESS_KEY=your_access_key
BYTEPLUS_SECRET_KEY=your_secret_key
SLACK_WEBHOOK_URL=
SERVER_IP=10.81.0.49
EOF
```

---

### 4) `sudo docker compose ...` failed after user-level plugin install

**Symptom**
- Running with `sudo` produced:
  - `unknown shorthand flag: 'd' in -d`

**Root cause**
- Compose plugin was installed under user path (`~/.docker/cli-plugins`) for `ec2-user`.
- `sudo` used root context and did not see that plugin.

**Fix**
- Add user to `docker` group and run compose without `sudo`:

```bash
sudo usermod -aG docker ec2-user
newgrp docker
```

Then use:

```bash
SERVER_IP=10.81.0.49 docker compose up -d
```

---

### 5) Loki failed to start due to port conflict (`3100`)

**Symptom**
- Compose failed with:
  - `bind: address already in use` on `0.0.0.0:3100`

**Root cause**
- Host-level Loki process was already listening on port `3100`.

**Fix**

```bash
sudo systemctl stop loki 2>/dev/null || true
sudo systemctl disable loki 2>/dev/null || true
sudo pkill -f '^.*loki.*$' 2>/dev/null || true
sudo ss -ltnp | awk 'NR==1 || /:3100\s/'
```

Then restart affected services:

```bash
SERVER_IP=10.81.0.49 docker compose up -d loki zabbix-server zabbix-web
```

---

### 6) Grafana kept restarting due to port conflict (`3000`)

**Symptom**
- Grafana container logs showed:
  - `failed to open listener on address 0.0.0.0:3000`
  - `bind: address already in use`
- `curl http://localhost:3000/api/health` returned version `12.4.0` (host Grafana), not container version `9.5.21`.

**Root cause**
- Host-level Grafana process was already listening on `3000`.

**Fix**

```bash
sudo systemctl stop grafana-server 2>/dev/null || true
sudo systemctl disable grafana-server 2>/dev/null || true
sudo pkill -f grafana 2>/dev/null || true
sudo ss -ltnp | awk 'NR==1 || /:3000\s/'
```

Restart container Grafana:

```bash
SERVER_IP=10.81.0.49 docker compose up -d grafana
```

Validate:

```bash
curl -sS http://localhost:3000/api/health
```

Expected version:
- `9.5.21`

---

### 7) eBPF exporter image build failed

**Symptom**
- `ebpf-exporter` build failed at `apt-get update` with:
  - `Clearsigned file isn't valid, got 'NOSPLIT'`
  - `does the network require authentication?`

**Root cause**
- Network/proxy/auth interception prevented normal Ubuntu apt repository access during image build.

**Fix options**
- Preferred: allow outbound access to Ubuntu apt repos from build environment.
- Alternative: configure `http_proxy` / `https_proxy` during build.
- Temporary workaround: start core services first and defer `ebpf-exporter`.

## Final Working Startup Steps (Amazon Linux)

Run these commands in order:

```bash
cd /home/ec2-user/telemetry

# 1) Docker + compose plugin checks
docker --version
docker compose version

# 2) Start Docker daemon
sudo systemctl enable --now docker

# 3) Ensure non-root docker access
sudo usermod -aG docker ec2-user
newgrp docker

# 4) Prepare environment variables
cat > .env << 'EOF'
BYTEPLUS_ACCESS_KEY=your_access_key
BYTEPLUS_SECRET_KEY=your_secret_key
SLACK_WEBHOOK_URL=
SERVER_IP=10.81.0.49
EOF

# 5) Free conflicting host ports/services
sudo systemctl stop loki grafana-server 2>/dev/null || true
sudo systemctl disable loki grafana-server 2>/dev/null || true
sudo pkill -f '^.*loki.*$' 2>/dev/null || true
sudo pkill -f grafana 2>/dev/null || true

# 6) Start core server-side services
SERVER_IP=10.81.0.49 docker compose up -d \
  prometheus alertmanager pushgateway loki grafana \
  zabbix-db zabbix-server zabbix-web
```

## Post-Start Verification

```bash
docker compose ps
curl -sS http://localhost:3000/api/health
curl -sS http://localhost:3100/ready
curl -sS http://localhost:9090/-/healthy
```

Expected:
- Grafana container is `Up`
- Grafana health returns database `ok`
- Loki `/ready` returns ready
- Prometheus healthy endpoint succeeds

## Service Endpoints

- Grafana: `http://10.81.0.49:3000`
- Prometheus: `http://10.81.0.49:9090`
- Alertmanager: `http://10.81.0.49:9093`
- Loki: `http://10.81.0.49:3100`
- Zabbix Web: `http://10.81.0.49:8080`
- Pushgateway: `http://10.81.0.49:9091`

## Notes

- Compose warning `version is obsolete` is non-blocking for Docker Compose v2.
- Missing `provisioning/plugins` or `provisioning/notifiers` directories in Grafana logs were not the crash cause in this case; port conflict on `3000` was the actual blocker.
