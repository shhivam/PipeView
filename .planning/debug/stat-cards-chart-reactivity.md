---
status: awaiting_human_verify
trigger: "Stat cards and charts don't auto-update; Y-axis labels overflow chart bounds"
created: 2026-03-25T00:00:00Z
updated: 2026-03-25T00:00:00Z
---

## Current Focus

hypothesis: CONFIRMED and FIXED — Both issues resolved. Awaiting human verification.
test: Build succeeded, all 50+ tests pass, no regressions
expecting: User confirms: (1) stat cards and charts auto-update without tab switching, (2) y-axis labels no longer overflow
next_action: Await user verification of the running app

## Symptoms

expected: "Today" / "This Week" / "This Month" stat cards and history bar charts should auto-update as new data arrives in real-time
actual: They stay stale and only refresh when user switches to Preferences tab and back to Dashboard. This has ALWAYS been the behavior.
errors: None
reproduction: Open popover → watch stat cards and charts → they don't change → go to Preferences tab → come back to Dashboard → now they show updated values
started: Always been this way since v1.0

Additionally: Y-axis labels ("1000 MB", "750 MB") overflow above the chart area and overlap with the interface breakdown section above.

## Eliminated

## Evidence

- timestamp: 2026-03-25T00:01:00Z
  checked: DashboardView.swift data loading pattern
  found: Lines 81-87 use `.task { loadChartData(); loadStats() }` and `.onChange(of: selectedRange) { loadChartData() }`. Both loadChartData() and loadStats() are synchronous one-shot reads via `appDatabase.dbWriter.read{}`. No GRDB ValueObservation, no @Query, no timer-based refresh. Data is fetched once when view appears and never again.
  implication: This is the root cause of stale stat cards and charts. The .task modifier runs when the view first appears. When user switches to Preferences tab, SwiftUI destroys DashboardView. Switching back re-creates it, triggering .task again — hence the "refresh on tab switch" behavior.

- timestamp: 2026-03-25T00:01:30Z
  checked: HistoryChartView.swift y-axis configuration
  found: Lines 144-154 configure chartYAxis with AxisMarks. The chart is wrapped in a ZStack (line 49) with a Group that has .frame(height: 200) on line 94. No .clipped() modifier is applied. The y-axis labels (especially the top label at yAxisMax) can render above the frame boundary.
  implication: Y-axis labels overflow because SwiftUI Chart renders axis labels outside the chart's frame, and there's no clipping to contain them.

- timestamp: 2026-03-25T00:02:00Z
  checked: Aggregation pipeline timing
  found: AppDelegate runs AggregationEngine.runFullAggregation() every 120 seconds. BandwidthRecorder writes raw samples every ~10 seconds. Chart queries read from aggregated tier tables (minute_samples, hour_samples, day_samples). So new data appears in tier tables every 2 minutes.
  implication: Even with reactive observation, updates will be limited by the 2-minute aggregation cycle. But that's expected behavior — the chart should update every ~2 minutes when new aggregated data lands.

- timestamp: 2026-03-25T00:05:00Z
  checked: Fix implementation and build verification
  found: |
    1. Added observeChartData() and observeCumulativeStats() to AppDatabase using GRDB ValueObservation.tracking{}
    2. Added CumulativeStats struct (Sendable, Equatable) to bundle all three stat periods atomically
    3. Rewrote DashboardView to use .task(id: selectedRange) for chart observation and .task{} for stats observation, both using for-try-await loops on ValueObservation async sequences
    4. Added .clipped() to HistoryChartView's chart Group after .frame(height: 200)
    5. Added .padding(.top, 4) to the ZStack to give topmost label rendering room
    6. Build succeeded, all tests pass
  implication: Both issues are addressed. Chart and stats now react to database changes. Y-axis labels are clipped to chart bounds.

## Resolution

root_cause: |
  Issue 1 (Reactivity): DashboardView fetches chart data and cumulative stats with one-shot synchronous reads inside .task{}. There is no GRDB ValueObservation or periodic refresh, so the view never updates after initial load. Tab switching destroys/recreates the view, triggering .task again — explaining the "refresh on tab switch" workaround.

  Issue 2 (Y-axis overflow): HistoryChartView has no .clipped() modifier on the chart container. Swift Charts renders axis labels (especially the topmost y-axis label) outside the frame boundary, causing them to overlap with content above.
fix: |
  Issue 1: Replace one-shot .task{} fetches with GRDB ValueObservation using async streaming. Create observation publishers for chart data and cumulative stats that emit new values whenever the underlying database tables change. Use .task{} with for-await-in loop to continuously receive updates.

  Issue 2: Add .clipped() to the chart frame and add top padding to prevent the topmost y-axis label from overflowing.
verification: |
  - Build: xcodebuild build succeeded with zero errors
  - Tests: all existing tests pass (TEST SUCCEEDED), zero regressions
  - Self-check: ValueObservation async sequences are properly cancelled via SwiftUI .task{} lifecycle
  - Self-check: .task(id: selectedRange) ensures chart observation restarts on range change
  - Self-check: CumulativeStats struct implements Equatable to enable GRDB deduplication
  - Self-check: .clipped() on chart frame prevents y-axis label overflow
  - Pending: Human verification of live app behavior
files_changed:
  - BandwidthMonitor/Persistence/AppDatabase.swift
  - BandwidthMonitor/Popover/DashboardView.swift
  - BandwidthMonitor/Popover/HistoryChartView.swift
