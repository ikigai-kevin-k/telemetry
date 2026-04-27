# Zabbix Network Panel Pass Notes (Server + ARO12 Agent)

## Goal
Make `AIPC Network Traffic - All Agents (MBps)` on server-side Grafana show valid network data for `GC-aro12-agent`, specifically the `Interface enp86s0: Bits received` metric from Zabbix.

## Environment
- Grafana on server side (`ikgserver1`)
- Zabbix UI/API available from server
- Agent host: `GC-ARO-001-2` (shown in Grafana as `GC-aro12-agent`)
- Network interface expected: `enp86s0`

## Problems Encountered

### 1) Panel remained `No data` in Grafana
**Symptom**
- `AIPC Network Traffic - All Agents (MBps)` showed no series even after Zabbix data source setup.

**Root Causes**
- Multiple panel queries were mixed, making troubleshooting difficult.
- Host/item selections were inconsistent across queries.
- Some fields were typed manually instead of selected from dropdown (risking mismatch with actual Zabbix item IDs).

---

### 2) `enp86s0` item not visible in Grafana dropdown (initially)
**Symptom**
- Could not find `Interface enp86s0: Bits received` in Grafana item selector.

**Root Cause**
- Grafana only lists items that are actually present/discovered in Zabbix for the selected host.
- At first, selection/filter state did not surface the expected item.

---

### 3) Needed to verify whether issue was server side or agent side
**Symptom**
- Zabbix and Grafana behavior did not match.

**Investigation**
- Agent-side check:
  - `ip -br link` confirmed `enp86s0` exists and is UP on `GC-ARO-001-2`.
- Zabbix-side check:
  - `Monitoring -> Latest data` was used to verify whether `enp86s0` metrics existed for the host.

**Conclusion**
- Agent interface existed; issue was in Zabbix item visibility/query selection path rather than missing OS interface.

## Fixes Applied

### A) Validate source metric in Zabbix first
1. Opened `Monitoring -> Latest data`.
2. Selected host `GC-aro12-agent` (or exact mapped host).
3. Verified network items were present and updated.

### B) Simplify Grafana panel query to minimum
1. Opened panel edit for `AIPC Network Traffic - All Agents (MBps)`.
2. Reduced query complexity (kept only required agent queries).
3. Ensured each query uses:
   - Data source: `Zabbix-New`
   - Query type: `Metrics`
   - Correct Group and Host
   - Item selected from dropdown (not manually typed)

### C) Final item mapping
- For `GC-aro12-agent`, selected:
  - `Interface enp86s0: Bits received`
- Applied alias/function formatting only after base data rendered successfully.

### D) Time range and refresh
- Used a wider range (`Last 24 hours` / `Last 7 days`) during verification.
- Refreshed panel after query updates to avoid false empty state.

## Final Working Query Pattern

Use one query per host first, confirm rendering, then expand:

- **Data source**: `Zabbix-New`
- **Query type**: `Metrics`
- **Group**: `Linux servers`
- **Host**: `GC-aro12-agent`
- **Item**: `Interface enp86s0: Bits received`
- **Functions**:
  - Start with none
  - Add alias and scaling only after data appears

## Validation (Passed)
- Zabbix `Latest data` shows network metrics for target host.
- Grafana item dropdown includes `Interface enp86s0: Bits received`.
- Network panel now renders data for aro12 instead of `No data`.

## Practical Lessons Learned
- Always verify metric existence in Zabbix before panel tuning in Grafana.
- Never troubleshoot with many mixed queries at once.
- In Zabbix datasource panels, prefer dropdown selection over manual typing for host/item fields.
- If dropdown does not show an item, check host selection, item discovery, and time range first.
