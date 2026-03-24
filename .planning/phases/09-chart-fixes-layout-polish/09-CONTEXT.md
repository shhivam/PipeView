# Phase 9: Chart Fixes & Layout Polish - Context

**Gathered:** 2026-03-24
**Status:** Ready for planning

<domain>
## Phase Boundary

Fix chart rendering issues across all time ranges (1H, 24H, 7D, 30D) — stabilize hover/selection interaction, fix bar grouping for 7D and 30D views, add human-readable y-axis labels, and verify stat card layout. Charts should render correctly with readable axes and stable interaction at every zoom level.

</domain>

<decisions>
## Implementation Decisions

### Chart hover stability (CHRT-01)
- Fix `.chartYScale(domain:)` to pre-computed max value from visible data points — locks y-axis range so selection/hover doesn't cause layout reflow
- Add ~10% headroom above max value to prevent bars touching top edge and give room for tooltip annotations
- Keep current RuleMark + tooltip interaction style — already implemented, just needs the y-axis domain fix

### 7D view axis labels (CHRT-02)
- X-axis labels: short date format (3/18, 3/19, 3/20...) — user preference over day-of-week abbreviations
- One bar per day — data already comes from `.day` aggregation tier, ensure exactly 7 data points

### 30D view axis labels (CHRT-03)
- X-axis labels: show every 5th day label with short date format ("Mar 1", "Mar 5"...) — prevents overlap while staying readable (6 labels across 30 days)
- One bar per day — same `.day` tier as 7D, ensure 30 data points

### Y-axis formatting (CHRT-04)
- Auto-scale: pick one unit for the entire axis based on max value (all KB, all MB, or all GB)
- Show unit suffix in axis title or labels (e.g., "MB" suffix on each tick)
- 4-5 ticks with round numbers (e.g., 0, 25, 50, 75, 100 MB) — clean look, enough precision

### Stat card layout (LYOT-01)
- Stat cards already look good after Phase 8 panel resize to 480x650 — wider panel gave cards enough room
- Verify-only: confirm text is not truncated at large byte values; if any edge case found, apply `.lineLimit(1)` + `.minimumScaleFactor(0.7)` as safety net
- No proactive code change planned — verify first

### Claude's Discretion
- Exact round-number tick calculation algorithm for y-axis
- Whether to use `.chartXAxis` modifier or custom `AxisMarks` for label formatting
- Internal implementation of the auto-scale unit picker (thresholds for KB→MB→GB transition)
- How to ensure exactly 7 or 30 data points are returned from the database query

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ByteFormatter` — already used in StatCardView and HistoryChartView tooltips for human-readable byte formatting
- `HistoryTimeRange` — enum with `.calendarUnit`, `.tier`, `.timeInterval` properties per range
- `ChartDataPoint` — model with `timestamp`, `totalBytesIn`, `totalBytesOut`

### Established Patterns
- Swift Charts with `BarMark` grouped by Direction (Download/Upload)
- `chartForegroundStyleScale` for Download=accentColor, Upload=secondary
- `chartXSelection` for interactive selection with `@State private var selectedTimestamp`
- `closestPoint(to:)` helper for snapping selection to nearest data point

### Integration Points
- `HistoryChartView` is composed inside `DashboardView` (from Phase 8)
- `CumulativeStatsView` wraps 3 `StatCardView` cards in HStack
- Data loaded via `AppDatabase.fetchChartData()` and `AppDatabase.fetchCumulativeStats()`
- Chart view receives `dataPoints: [ChartDataPoint]` and `timeRange: HistoryTimeRange`

</code_context>

<specifics>
## Specific Ideas

- User specifically wants short numeric date format (3/18) for 7D x-axis, not day-of-week names
- LYOT-01 may already be resolved by Phase 8's panel resize — verify before changing code

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>
