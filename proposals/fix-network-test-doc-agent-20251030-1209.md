# Proposal: Add iperf3 Network Test Guide for Agent PCs

## Background & Problem
We need a quick, reliable way to generate inbound traffic on agent PCs (e.g., ARO-002-1 at `100.64.0.144`) to verify that the Zabbix item `Interface eth0: Bits received` in Grafana actually changes when packets are received.

## Scope & Impact
- Audience: Operators who want to validate network RX telemetry for any agent PC.
- Outcome: A small markdown guide committed under the repository that describes a minimal sender/receiver iperf3 workflow to create measurable inbound traffic.
- Risk: Very low. Pure documentation; the runtime environment is unaffected.

## Proposed Change (Agent-side repository)
Create a new file at repository root:

- `network-test-method.md`

Content outline:

### Packet Receiver (run on the agent PC)
```bash
iperf3 -s -1
```
Notes:
- `-1` makes the server exit after a single test, which prevents it from lingering.

### Packet Sender (run from a tester machine on the same network)
```bash
iperf3 -c 100.64.0.144 -t 20
```
Notes:
- Replace `100.64.0.144` with the target agent PC address when testing others.
- `-t 20` runs for 20 seconds, which is long enough to show a visible RX rise.

### Optional: UDP or Target Rate
```bash
# Example: 30 Mbps UDP for 20 seconds
iperf3 -u -b 30M -c 100.64.0.144 -t 20
```
Notes:
- UDP allows specifying a target rate with `-b` and typically makes a flat plateau in the Grafana RX graph.

## Validation Steps
1. Start the receiver on the agent PC: `iperf3 -s -1`.
2. Start the sender from a tester machine: `iperf3 -c 100.64.0.144 -t 20` (or the UDP variant).
3. Open Grafana panel for the agent: `Interface eth0: Bits received`.
4. Set the time range to "Last 15 minutes" and refresh after 30–60 seconds.
5. Expect to see a clear spike (TCP) or plateau (UDP at fixed rate) on RX.

## Rollback
Documentation-only change. If needed, simply delete `network-test-method.md` via a revert commit.


