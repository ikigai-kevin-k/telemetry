## Grafana: Connect adjacent samples with line segments (Connect null values)

This guide explains how to connect adjacent sample points with lines in the AIPC Temperature (Time series) panel of the System Overview dashboard, improving the visual “discrete” look.

### Background
- Metric: `system_temperature_celsius`
- Agent-side push: every 10s (Pushgateway)
- Prometheus scrape: every 15s
- When Grafana increases the step automatically or encounters nulls, it does not connect points by default, making the chart look like sparse dots.

### Steps (Time series panel)
1. Open the panel and click Edit.
2. In the right settings pane, use the search box and type "connect".
3. In the results, find: `Graph styles → Connect null values`.
4. Set the option to "Always".
5. Also ensure Draw style is set to "Lines" (you can keep Points enabled to show sample markers).
6. Save the panel (Save/Apply).

After this, line segments will connect between adjacent sample points, making the visualization more continuous.

### Advanced suggestions (avoid overly sparse points)
- In Query options:
  - Set Step/Min interval to `15s` (equal to or smaller than the Prometheus scrape interval).
  - Increase Max data points (e.g., `3000`) to avoid automatic step inflation.

### Verification
- In Explore or the panel, set the time range to Last 1h and confirm that the lines are connected and the spacing is no longer exaggerated.
- If there are still occasional gaps, check whether there are blank intervals longer than the step, or whether Max data points is too small causing the step to be increased.


