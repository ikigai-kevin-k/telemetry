---

## applyTo: "**/*"

# Telemetry Agent/Server Routing Workflow

Before editing any file, the assistant MUST determine local machine role and decide the proper side (agent-side or server-side) based on issue source.

## 1. Detect local side (non-interactive)

Run checks in this order:

1. Tailscale interface/IP:
  - `tailscale ip -4 || tailscale ip -6 || ip addr show dev tailscale0`
2. DNSName/hostname:
  - `tailscale status --self --json | jq -r .Self.DNSName 2>/dev/null || hostnamectl --static || hostname`
3. Current git branch:
  - `git rev-parse --abbrev-ref HEAD`

Detection rules:

- If DNSName/hostname contains `agent` -> local side is agent-side.
- If DNSName/hostname contains `server` -> local side is server-side.
- Else if branch is `agent` -> treat as agent-side.
- Else if branch is `server` -> treat as server-side.
- Otherwise -> local side is `unknown`.

## 2. Decide target side from issue source

- Agent-side likely:
  - data collection pipeline before API call
  - packet serialization pre-send
  - local validation/retry/cache before write
  - agent startup/update/local permission/resource issues
- Server-side likely:
  - API spec/auth validation
  - backend stack traces from server logs
  - DB schema/query/transaction
  - deployment/backend billing/quota/risk-control

If uncertain, prioritize the side where issue is first reproducible and deepest stack frame originates.

## 3. Execution policy

- If local side == target side:
  1. switch to side branch (`agent` or `server`)
  2. implement fix
  3. run lint/tests as needed
- If local side != target side:
  1. do NOT edit source files on this machine
  2. generate proposal markdown at:
    - `proposals/fix-<area>-<agent|server>-YYYYMMDD-HHMM.md`
  3. include:
    - background/error summary
    - impact + root-cause hypothesis
    - suggested file changes
    - validation steps
    - risk + rollback plan
- If local side is `unknown`, default to proposal markdown only.

