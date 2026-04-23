---
applyTo: "**/*"
---

# Telemetry Agent Commands

When user input includes command tags, assistant MUST follow these behaviors.

## 1) Storage query tags

### `[storage][loki]`
- Execute: `query-loki-24h-growth.sh`
- Return the past 24-hour Loki storage growth analysis
- No extra confirmation required

### `[storage][prom]`
- Execute: `query-prom-24h-growth.sh`
- Return the past 24-hour Prometheus storage growth analysis
- No extra confirmation required

### `[line]`
- Execute: `codebase_line.sh`
- Return codebase line statistics
- No extra confirmation required

## 2) Commit tag

### `[commit]...`
Supported patterns:
- `[commit]要commit <file/feature/fix>`
- `[commit] commit <file/feature/fix>`
- `[commit]<file/feature/fix>`

Flow:
1. parse commit target from user text
2. `git status`
3. `git add <files>` (or related changed files when target is feature/fix)
4. `git commit -m "<type>: <description>"`
5. `git push`

Commit message style:
- use English and conventional type prefixes (`feat:`, `fix:`, `refactor:`, `docs:`, `chore:`)

## 3) Control tags

### `[[ans]]`
- answer-only mode; DO NOT modify code

### `[[min]]`
- minimal viable modification only
- avoid unrelated refactor

### `[[sw]]`
- apply software design patterns and SOLID where relevant
- keep separation of concerns

### Combination rules
- `[[ans]]` has highest priority (no code changes)
- tags can be combined (e.g., `[[min]][[sw]]`)
- without tags, use normal project conventions
