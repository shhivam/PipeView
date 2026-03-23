# Phase 5: Historical Charts, Statistics, and Settings - Context

**Gathered:** 2026-03-24
**Status:** Ready for planning

<domain>
## Phase Boundary

Historical bandwidth charts with switchable time ranges, cumulative usage statistics, and a full preferences interface. This phase completes the popover experience: a new "History" tab with bar charts and stats cards, plus replacing the Preferences placeholder with actual settings controls. Live metrics (Phase 4) remain untouched.

</domain>

<decisions>
## Implementation Decisions

### Navigation & Layout
- **D-01:** Three tabs in the popover: Metrics (live data), History (charts + stats), Preferences (settings). Segmented control at top, consistent with Phase 4 pattern
- **D-02:** Expand popover to ~400x550 to give charts breathing room (Phase 4 D-13 spacious feel)
- **D-03:** History tab layout: time range picker at top → chart → cumulative stats cards below. Chart is the hero element
- **D-04:** Time range selector is a segmented control with "1H | 24H | 7D | 30D" options — consistent with the existing tab segmented control style

### Chart Design
- **D-05:** Bar chart type — discrete bars per time bucket, clear visual separation between periods. Uses Swift Charts BarMark
- **D-06:** Two grouped/side-by-side bar marks per bucket — download in accent color, upload in secondary color, shared X axis
- **D-07:** Aggregate data only in charts (not per-interface breakdown) — cleaner, matches "at a glance" philosophy
- **D-08:** Interactive with hover/tap tooltip — shows exact value + timestamp at the selected point. Uses Swift Charts chartOverlay or chartXSelection

### Cumulative Statistics
- **D-09:** Total bytes combined (in+out) as the primary number per card, with small per-direction breakdown below (up-arrow X / down-arrow Y)
- **D-10:** Auto-scaled human-readable formatting (e.g., "1.2 GB", "45.3 GB") — consistent with SpeedFormatter patterns
- **D-11:** Horizontal row of 3 compact cards below the chart: Today | This Week | This Month
- **D-12:** Empty state: chart shows zero baseline with centered "No data yet" overlay text

### Preferences Interface
- **D-13:** Four settings: display mode (auto/both/upload/download), unit preference (auto/KB/MB/GB), update interval (1s/2s/5s), launch-at-login toggle
- **D-14:** UserDefaults with @AppStorage for SwiftUI bindings — native, simple persistence
- **D-15:** Settings take effect immediately on change — standard macOS behavior, no save/apply button
- **D-16:** Grouped Form with Section layout: "Display" section (mode, unit) and "Advanced" section (interval, login item)

### Claude's Discretion
- Exact chart colors and opacity for download vs upload bars
- Bar width and spacing within Swift Charts
- Tooltip formatting and positioning
- How @AppStorage keys are named and how changes propagate to StatusBarController
- SMAppService toggle implementation details
- How to map time ranges to aggregation tiers (1H → minute_samples, 24H → hour_samples, 7D → hour_samples or day_samples, 30D → day_samples)
- AppDatabase query methods design (static vs instance, async vs sync)
- GRDBQuery @Query usage vs manual database reads for chart data
- Chart axis labels and formatting (time format per range)
- ScrollView behavior if stats cards overflow

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Architecture & Stack
- `CLAUDE.md` — Swift Charts framework (macOS 13+), GRDB.swift 7.10.0, GRDBQuery 0.11.0, hybrid AppKit+SwiftUI architecture, @AppStorage and UserDefaults patterns

### Requirements
- `.planning/REQUIREMENTS.md` — POP-02 (historical bar/area charts with switchable time ranges), POP-04 (cumulative stats: today, this week, this month), SYS-02 (preferences interface for display options and update interval)

### Phase 3 Data Layer
- `.planning/phases/03-data-persistence-and-aggregation/03-CONTEXT.md` — D-12 (aggregated tiers store totalBytesIn/Out + peakBytesInPerSec/OutPerSec), D-13 (per-interface at all tiers), D-01 (10-second raw samples), D-07 (raw retained 24h)

### Phase 4 Popover Foundation
- `.planning/phases/04-popover-shell-and-interface-views/04-CONTEXT.md` — D-04 (segmented control tabs), D-13/D-14 (spacious layout, semantic colors), D-15 (popover ~400x500 now expanding to 550)

### Phase 2 Formatting
- `.planning/phases/02-menu-bar-display/02-CONTEXT.md` — DisplayMode enum (auto/both/uploadOnly/downloadOnly), SpeedFormatter.UnitMode (auto/fixedKB/fixedMB/fixedGB)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `SpeedFormatter` (MenuBar/SpeedFormatter.swift): format(bytesPerSecond:unit:) — reuse for chart tooltips and stats formatting
- `SpeedTextBuilder` (MenuBar/SpeedTextBuilder.swift): DisplayMode enum — reuse for preferences picker options
- `PopoverTab` (Popover/PopoverTab.swift): Extend with `.history` case
- `PopoverContentView` (Popover/PopoverContentView.swift): Add History tab routing, update frame height
- `PreferencesPlaceholderView` (Popover/PreferencesPlaceholderView.swift): Replace with actual PreferencesView
- `AggregatedRecord` protocol (Persistence/Models/AggregatedSample.swift): Shared fields for all tier types — query target for charts
- Five tier types: MinuteSample, HourSample, DaySample, WeekSample, MonthSample — each with totalBytesIn/Out, peakBytesInPerSec/OutPerSec, sampleCount
- `AppDatabase` (Persistence/AppDatabase.swift): Add fetch methods for chart data queries
- `Loggers.swift`: Add `.charts` or `.history` logger category if needed

### Established Patterns
- @MainActor @Observable for state (NetworkMonitor) — SwiftUI views observe directly
- Semantic colors only (.primary, .secondary, .accentColor) — Phase 4 D-14
- Segmented control Picker with .segmented style for tab switching
- Sendable value types for data models
- StatusBarController uses hardcoded DisplayMode/UnitMode — needs to read from UserDefaults

### Integration Points
- `StatusBarController` (MenuBar/StatusBarController.swift): Currently hardcodes `displayMode: .auto` and `unitMode: .auto` — must observe @AppStorage changes
- `NetworkMonitor` (Monitoring/NetworkMonitor.swift): `pollingInterval` property — preferences can update this
- `AppDelegate.swift`: May need to wire preferences observation
- `AppDatabase`: No query methods yet — must add fetch-by-tier-and-time-range for chart data

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 05-historical-charts-statistics-and-settings*
*Context gathered: 2026-03-24*
