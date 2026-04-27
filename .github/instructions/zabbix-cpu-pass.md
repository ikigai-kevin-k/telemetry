# Zabbix CPU Panel Pass Notes (ARO12 on Server-side Grafana)

## Goal
Show `aro12` agent CPU usage correctly in the server-side Grafana `System Overview` dashboard using Zabbix data source.

## Initial Symptoms
- `AIPC - CPU Usage` panel showed `No data`.
- Zabbix host data existed in Zabbix UI (`Latest data`), but Grafana panel still empty.
- Opening `Zabbix-New` data source page sometimes triggered a front-end error.

## Key Issues Found

### 1) Data source query path mismatch
- Dashboard panel was originally designed for Prometheus.
- Even after adding Zabbix plugin, panel still had no valid Zabbix data flow until query was switched and simplified.

### 2) Zabbix plugin UI crash in Grafana
- Error observed:
  - `Minified React error #130`
  - stack trace from `alexanderzobnin-zabbix-app/datasource/module.js`
- Environment details:
  - Grafana version: `9.5.21`
  - Installed Zabbix plugin: `4.6.1`
- Root cause:
  - Plugin version compatibility issue with current Grafana major/minor version.

### 3) Zabbix API credential lock
- In Explore/Data source test, credential/authentication error was seen (`application password ... blocked`).
- This prevented Grafana from retrieving data, even if panel query was correct.

## Fixes Applied

### A) Reinstall a compatible Zabbix plugin version
1. Removed incompatible plugin version.
2. Restarted Grafana container.
3. Installed a Grafana-9-compatible Zabbix plugin version (`4.4.x` line).
4. Restarted Grafana again.
5. Verified plugin version with:
   - `grafana-cli plugins ls`

### B) Resolve API authentication block
1. Unblocked/reset the Zabbix API user credentials in Zabbix.
2. Updated credentials in Grafana `Zabbix-New` data source.
3. Ran `Save & test` until connection succeeded.

### C) Rebuild panel query with minimal Zabbix settings
1. Opened `System Overview` -> `AIPC - CPU Usage` -> `Edit`.
2. Set `Data source` to `Zabbix-New`.
3. Cleared extra/legacy queries.
4. Used one clean query:
   - `Group`: `Linux servers`
   - `Host`: `GC-aro12-agent`
   - `Item`: `Linux: CPU utilization` (or the exact CPU item that has values in Zabbix)
5. Set time range to `Last 24 hours` for verification.
6. Applied and saved dashboard.

## Validation Checklist (Passed)
- `Zabbix-New` data source page opens without React crash.
- `Save & test` succeeds.
- Explore returns data from `GC-aro12-agent`.
- `AIPC - CPU Usage` panel displays aro12 CPU series instead of `No data`.

## Final Working Steps (Repeatable)
1. Ensure Zabbix plugin version is compatible with current Grafana.
2. Ensure Zabbix API user is not blocked and credentials are valid.
3. Use a single clean Zabbix query in panel first (no mixed/legacy queries).
4. Confirm item has real values in Zabbix `Latest data`.
5. Save panel and dashboard after visual confirmation.

## Notes
- If panel goes blank again after upgrade, re-check plugin compatibility first.
- If Explore works but panel is empty, re-check panel filters/time range and item selection.
