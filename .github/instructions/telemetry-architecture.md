---
applyTo: "**/*"
---

# Telemetry Architecture (Agent + Server)

This document describes the service architecture, topology, and data flow
for the `telemetry` project using Mermaid diagrams.

## 1) High-Level Topology

```mermaid
flowchart LR
    subgraph AGENTS["Agent Nodes (multiple sites)"]
        A1["GC-aro12\nPromtail + Zabbix Agent"]
        A2["GC-ARO-001-1\nPromtail + Zabbix Agent"]
        A3["GC-ARO-001-2\nPromtail + Zabbix Agent"]
        A4["GC-ARO-002-1 / 002-2 / ASB-001-1\nPromtail + Zabbix Agent"]
    end

    subgraph SERVER["Server Node (GE/TPE)"]
        LOKI["Loki Server :3100"]
        PROM["Prometheus :9090"]
        AM["Alertmanager :9093"]
        GRAF["Grafana :3000"]
        PG["Pushgateway :9091"]
        ZS["Zabbix Server :10051"]
        ZW["Zabbix Web :8080"]
        ZDB["MySQL (Zabbix DB)"]
        EBPF["eBPF Exporter :9300"]
        DUE["Disk Usage Exporter :9275"]
        TG["Telegraf ZCAM :9273 (optional)"]
        ZVE["ZCAM Values Exporter :9274 (optional)"]
        WEBHOOK["Grafana Webhook Service (host mode)"]
    end

    A1 -->|log push /loki/api/v1/push| LOKI
    A2 -->|log push| LOKI
    A3 -->|log push| LOKI
    A4 -->|log push| LOKI

    A1 -->|active/passive checks| ZS
    A2 -->|active/passive checks| ZS
    A3 -->|active/passive checks| ZS
    A4 -->|active/passive checks| ZS

    PROM -->|alerts| AM
    AM -->|webhook| WEBHOOK
    GRAF -->|query logs| LOKI
    GRAF -->|query metrics| PROM
    ZW --> ZS
    ZS --> ZDB
    PROM -->|scrape| PG
    PROM -->|scrape| EBPF
    PROM -->|scrape| DUE
    PROM -->|scrape| TG
    PROM -->|scrape| ZVE
```

## 2) Server-Side Service Architecture

```mermaid
flowchart TB
    subgraph OBS["Observability Plane"]
        LOKI["Loki\n- auth_enabled: false\n- filesystem chunks/index\n- retention: 7d"]
        PROM["Prometheus\n- scrape/evaluate: 15s\n- retention: 200h"]
        AM["Alertmanager\n- Slack webhook routing"]
        GRAF["Grafana\n- provisioned datasources/dashboards"]
    end

    subgraph METRICS["Metric Producers"]
        EBPF["eBPF Exporter"]
        DUE["Disk Usage Exporter"]
        PG["Pushgateway"]
        TG["Telegraf ZCAM (optional)"]
        ZVE["ZCAM Values Exporter (optional)"]
        EXT["External targets\n(studio-web-player, agent exporters)"]
    end

    subgraph OPS["Operations / Integrations"]
        WEBHOOK["Grafana Webhook Service"]
        SLACK["Slack"]
    end

    subgraph ZABBIX["Zabbix Plane"]
        ZS["Zabbix Server"]
        ZW["Zabbix Web"]
        ZDB["MySQL"]
    end

    METRICS -->|/metrics scrape| PROM
    EXT -->|/metrics scrape| PROM
    PROM -->|alert rules| AM
    AM -->|notification webhook| WEBHOOK
    WEBHOOK -->|message delivery| SLACK

    GRAF -->|read metrics| PROM
    GRAF -->|read logs| LOKI

    ZW --> ZS
    ZS --> ZDB
```

## 3) Agent-Side Service Architecture

```mermaid
flowchart TB
    subgraph LOG_SOURCES["Local Log Sources on Agent"]
        LS1["/var/log/mock_sicbo.log"]
        LS2["/var/log/server.log"]
        LS3["/var/log/tmux-client.log"]
        LS4["/var/log/sdp.log"]
        LS5["/var/log/network_stats.log"]
    end

    PT["Promtail Agent\n- parse regex/json stages\n- attach labels: job, instance, interface, etc."]
    LOKI["Remote Loki Server\nhttp://<server-ip>:3100/loki/api/v1/push"]

    ZA["Zabbix Agent2"]
    ZS["Remote Zabbix Server :10051"]

    LS1 --> PT
    LS2 --> PT
    LS3 --> PT
    LS4 --> PT
    LS5 --> PT
    PT -->|batched log streams| LOKI

    ZA -->|active/passive monitoring| ZS
```

## 4) Log Data Flow (End-to-End)

```mermaid
sequenceDiagram
    participant App as Agent App/Services
    participant File as Local Log Files
    participant Promtail as Promtail Agent
    participant Loki as Loki Server
    participant Grafana as Grafana

    App->>File: Write logs (server/sdp/network/etc.)
    Promtail->>File: Tail files by scrape_configs
    Promtail->>Promtail: Parse pipeline stages (regex/json/timestamp/labels)
    Promtail->>Loki: Push log batches (/loki/api/v1/push)
    Loki->>Loki: Index + store chunks on filesystem
    Grafana->>Loki: Query logs (labels/LogQL)
    Loki-->>Grafana: Return streams and log lines
```

## 5) Metrics and Alert Data Flow

```mermaid
sequenceDiagram
    participant Exporter as Exporters / Targets
    participant Prom as Prometheus
    participant AM as Alertmanager
    participant Webhook as Webhook Service
    participant Slack as Slack
    participant Grafana as Grafana

    Exporter->>Prom: Expose /metrics
    Prom->>Exporter: Periodic scrape
    Prom->>Prom: Evaluate alert rules
    Prom->>AM: Send firing/resolved alerts
    AM->>Webhook: Forward alert webhook
    Webhook->>Slack: Send notification
    Grafana->>Prom: Query metrics for dashboards
```

## 6) Network and Deployment Topology Notes

- Server mode is designed for GE/TPE environments (for example, GE:
  `100.64.0.113`, TPE: `100.64.0.160`).
- Agent nodes run lightweight services only (Promtail + Zabbix Agent).
- Logs are centralized in Loki; metrics are centralized in Prometheus.
- Grafana is the unified visualization layer for both logs and metrics.
- Zabbix remains a parallel monitoring plane with its own database and web UI.
- Optional stacks (`telegraf-zcam`, `zcam-values-exporter`) join the same
  `telemetry_monitoring` network and are scraped by Prometheus.
