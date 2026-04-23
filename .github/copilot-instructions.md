# GitHub Copilot Instructions

This file provides global context for GitHub Copilot in `telemetry`.
Domain-specific rules live in `.github/instructions/*.instructions.md` using YAML `applyTo`.

## 1. Project overview

`telemetry` is an observability and log ingestion stack centered on:
- Loki server + Promtail agents
- Prometheus + exporters
- Grafana dashboards/provisioning
- Alerting and helper automation scripts

The repository contains both server-side and agent-side runtime assets, plus operational scripts for deployment, diagnostics, and storage analysis.

## 2. Tech stack

- Docker Compose (multi-service stack)
- Loki / Promtail
- Prometheus / Alertmanager
- Grafana provisioning
- Bash + Python helper scripts

## 3. Global coding and operation guidelines

- Keep code and operational scripts readable and explicit.
- Comments in code should be in English.
- Prefer safe, non-interactive shell operations for automation.
- Do not hardcode credentials into source files; prefer environment variables.
- For operational changes, preserve backward compatibility of existing scripts whenever possible.

## 4. Instruction files

| File | `applyTo` (exact) | Purpose |
|---|---|---|
| `telemetry-agent-server-routing.instructions.md` | `**/*` | Pre-edit side detection and branch routing rules |
| `telemetry-agent-commands.instructions.md` | `**/*` | Tag command behaviors from `.cursorrules` |
| `telemetry-coding.instructions.md` | `**/*` | Coding style and modification principles |

## 5. Skills

- `.github/skills/instructions/SKILL.md` (instruction index)
- `.github/skills/instructions/coding.instructions.md`
- `.github/skills/instructions/testing.instructions.md`
- `.github/skills/instructions/refactoring.instructions.md`
