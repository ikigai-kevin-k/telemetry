---
applyTo: "**/*"
---

# Telemetry Coding and Script Guidelines

## Style

- Prioritize clarity and maintainability over micro-optimizations.
- Keep functions focused; avoid deep nesting.
- Use explicit error handling and actionable logging.
- Use English for code comments.

## Configuration and secrets

- Never hardcode secrets in source files.
- Use environment variables or external secret stores.
- Keep operational endpoints configurable.

## Script safety

- Prefer non-interactive flags for scripts.
- Fail fast in automation scripts (`set -e` when appropriate).
- Preserve existing script interfaces unless user explicitly requests breaking changes.
