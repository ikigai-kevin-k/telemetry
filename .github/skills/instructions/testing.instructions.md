# Testing - telemetry

- Validate changed scripts/services with the smallest meaningful verification command.
- Prefer service health checks (`/ready`, `/metrics`, container status) for observability components.
- For config updates, verify syntax and startup behavior.
- Include rollback-safe verification steps whenever operational behavior changes.
