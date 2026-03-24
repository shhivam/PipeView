---
status: awaiting_human_verify
trigger: "chart-xaxis-sparse-data: Bar chart x-axis doesn't span the full time range for 24H/7D/30D views when data is sparse"
created: 2026-03-25T00:00:00Z
updated: 2026-03-25T00:15:00Z
---

## Current Focus

hypothesis: CONFIRMED and FIXED — Missing .chartXScale(domain:) was the root cause. Fix applied and build+tests verified.
test: Build succeeded, all tests pass, no regressions
expecting: User confirms chart x-axis spans full time range for all views (1H, 24H, 7D, 30D) even with sparse data
next_action: Await human verification of the running app

## Symptoms

expected: When selecting 30D (or 24H, 7D) time range, the x-axis should span the full time period (e.g., last 30 days from today) even if there's no data for most days. Bars should appear at their correct positions within the full range.
actual: The x-axis only covers dates where data exists. In the 30D view, only "Mar 23" appears on the x-axis with a single bar, making it look like the entire chart is just that one date. The chart doesn't show the empty days before or after.
errors: No errors - it's a visual/UX issue with chart domain configuration.
reproduction: Open the bandwidth monitor popover, select 30D time range. If you only have a few days of data, the chart x-axis will be compressed to only those dates.
started: Likely since charts were implemented. The issue becomes apparent when there's sparse data coverage.

## Eliminated

## Evidence

- timestamp: 2026-03-25T00:05:00Z
  checked: HistoryChartView.swift chart configuration
  found: Line 148 has .chartYScale(domain: 0...yAxisMax) explicitly setting y-axis domain. There is NO .chartXScale(domain:) modifier anywhere in the file. The chart's x-axis domain is entirely auto-determined by Swift Charts based on the data points present.
  implication: This is the root cause. When data is sparse (e.g., only Mar 23 data in a 30D view), Swift Charts compresses the x-axis to only the dates that have data, instead of showing the full Feb 23 - Mar 25 range.

- timestamp: 2026-03-25T00:06:00Z
  checked: DashboardView.swift data loading
  found: Line 107 computes `since = Date.now.addingTimeInterval(-selectedRange.timeInterval)` to query data. HistoryTimeRange.timeInterval provides the full span (e.g., 2_592_000 for 30D). The `since` date is already the correct range start — but it's only used for the DB query, never passed to the chart for domain setting.
  implication: The range start date is already computed. It just needs to be passed to HistoryChartView so it can set .chartXScale(domain: rangeStart...now).

- timestamp: 2026-03-25T00:07:00Z
  checked: HistoryTimeRange.swift
  found: HistoryTimeRange already has timeInterval property. The calendarUnit property provides the bar grouping unit. All the infrastructure is there — just the x-axis domain is missing.
  implication: Fix is straightforward: compute domain from timeRange in HistoryChartView itself (Date.now - timeRange.timeInterval ... Date.now).

## Resolution

root_cause: HistoryChartView applies .chartYScale(domain:) to lock the y-axis but has no corresponding .chartXScale(domain:) for the x-axis. Swift Charts auto-sizes the x domain to only span data points present. With sparse data, the axis compresses to only dates that have data, making the chart misleading.
fix: Add .chartXScale(domain:) to HistoryChartView.chartBase computed property, using the selected time range to compute the full domain (Date.now - timeRange.timeInterval ... Date.now). This ensures the x-axis always spans the complete selected period.
verification: |
  - Build: xcodebuild build succeeded with zero errors
  - Tests: all existing tests pass (TEST SUCCEEDED), zero regressions
  - Self-check: xDomainStart computes Date.now - timeRange.timeInterval, matching the same logic DashboardView uses for DB queries
  - Self-check: .chartXScale(domain: xDomainStart...Date.now) mirrors the existing .chartYScale(domain:) pattern
  - Self-check: Fix is minimal — 5 lines added (1 computed property + 1 modifier + comments), no existing code changed
  - Pending: Human verification of live app behavior
files_changed: [BandwidthMonitor/Popover/HistoryChartView.swift]
