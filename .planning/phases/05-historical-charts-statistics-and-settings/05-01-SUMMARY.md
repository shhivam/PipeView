---
phase: 05-historical-charts-statistics-and-settings
plan: 01
subsystem: database, shared-types
tags: [swift, grdb, sqlite, byte-formatting, preferences, time-range, chart-data]

# Dependency graph
requires:
  - phase: 03-data-persistence-and-aggregation
    provides: "AppDatabase, AggregatedSample types (MinuteSample, HourSample, etc.), AggregationTier enum"
  - phase: 02-menu-bar-display
    provides: "SpeedFormatter.UnitMode, DisplayMode enum"
provides:
  - "PreferenceKey constants, DisplayModePref, UnitModePref, UpdateIntervalPref enums with conversion methods"
  - "ByteFormatter for total byte formatting with adaptive precision"
  - "HistoryTimeRange enum mapping chart ranges to aggregation tiers"
  - "ChartDataPoint value type for chart data consumption"
  - "AppDatabase.fetchChartData(tier:since:) query method"
  - "AppDatabase.fetchCumulativeStats(since:) query method"
affects: [05-02-history-tab, 05-03-preferences-ui]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Extension-based query methods on AppDatabase for separation of concerns"
    - "Raw SQL with GRDB Row.fetchAll for aggregation queries (GROUP BY, SUM)"
    - "Preference enums with toDisplayMode()/toUnitMode() bridging to existing types"
    - "ByteFormatter mirroring SpeedFormatter adaptive precision pattern (no /s suffix)"

key-files:
  created:
    - BandwidthMonitor/Shared/PreferenceKeys.swift
    - BandwidthMonitor/Shared/ByteFormatter.swift
    - BandwidthMonitor/Shared/HistoryTimeRange.swift
    - BandwidthMonitor/Shared/ChartDataPoint.swift
    - BandwidthMonitorTests/ByteFormatterTests.swift
    - BandwidthMonitorTests/PreferencesTests.swift
    - BandwidthMonitorTests/HistoryDataTests.swift
    - BandwidthMonitorTests/AppDatabaseChartTests.swift
  modified:
    - BandwidthMonitor/Persistence/AppDatabase.swift
    - BandwidthMonitor.xcodeproj/project.pbxproj

key-decisions:
  - "AppDatabaseChartTests in separate file from existing AppDatabaseTests to avoid merge conflicts"
  - "fetchCumulativeStats queries hour_samples (not day_samples) for partial-day accuracy"
  - "fetchChartData uses raw SQL GROUP BY for interface aggregation rather than GRDB query interface"

patterns-established:
  - "Shared/ directory for cross-cutting types used by multiple layers (UI, persistence)"
  - "Preference enums with String/Int raw values and conversion methods to existing domain types"

requirements-completed: [POP-02, POP-04, SYS-02]

# Metrics
duration: 9min
completed: 2026-03-24
---

# Phase 5 Plan 1: Data Layer Foundation Summary

**Shared types, preference enums, byte formatter, history time ranges, and AppDatabase chart/stats queries with 42 passing tests**

## Performance

- **Duration:** 9 min
- **Started:** 2026-03-24T05:33:35Z
- **Completed:** 2026-03-24T05:43:22Z
- **Tasks:** 2
- **Files modified:** 10

## Accomplishments
- Created 4 new shared type files in BandwidthMonitor/Shared/ establishing contracts for History tab and Preferences UI
- Added fetchChartData and fetchCumulativeStats query methods to AppDatabase with interface aggregation
- Full TDD cycle (RED-GREEN) for both tasks with 42 new tests all passing
- Zero regressions across the full test suite

## Task Commits

Each task was committed atomically:

1. **Task 1: Create shared types and preference enums with tests**
   - `72072d9` (test): add failing tests for shared types and preference enums
   - `081e1c8` (feat): implement shared types and preference enums

2. **Task 2: Add AppDatabase chart and stats query methods with tests**
   - `04d8962` (test): add failing tests for AppDatabase chart and stats queries
   - `7f14b8a` (feat): implement AppDatabase chart and cumulative stats queries

_Note: TDD tasks have two commits each (test RED + feat GREEN)_

## Files Created/Modified
- `BandwidthMonitor/Shared/PreferenceKeys.swift` - PreferenceKey constants, DisplayModePref/UnitModePref/UpdateIntervalPref enums with conversion methods
- `BandwidthMonitor/Shared/ByteFormatter.swift` - Total byte formatting (KB/MB/GB) with adaptive precision matching SpeedFormatter
- `BandwidthMonitor/Shared/HistoryTimeRange.swift` - 1H/24H/7D/30D ranges with tier mapping, timeInterval, calendarUnit
- `BandwidthMonitor/Shared/ChartDataPoint.swift` - Identifiable+Sendable value type for chart consumption
- `BandwidthMonitor/Persistence/AppDatabase.swift` - Added fetchChartData and fetchCumulativeStats extension methods
- `BandwidthMonitorTests/ByteFormatterTests.swift` - 7 tests for byte formatting boundaries
- `BandwidthMonitorTests/PreferencesTests.swift` - 14 tests for enum roundtrips and conversions
- `BandwidthMonitorTests/HistoryDataTests.swift` - 14 tests for time range mapping and ChartDataPoint
- `BandwidthMonitorTests/AppDatabaseChartTests.swift` - 7 tests for chart data and cumulative stats queries

## Decisions Made
- Used separate AppDatabaseChartTests file rather than appending to existing AppDatabaseTests to keep test files focused
- fetchCumulativeStats queries hour_samples table (not day_samples) because hour_samples has more current partial-day data
- Used raw SQL with GRDB Row.fetchAll for aggregation queries where GROUP BY + SUM is cleaner than the GRDB query interface
- ChartDataPoint uses UUID for Identifiable conformance (simple, no collision concerns for chart rendering)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- All shared types ready for History tab (Plan 02) and Preferences UI (Plan 03)
- HistoryTimeRange.tier provides direct mapping to AggregationTier for fetchChartData
- Preference enums bridge cleanly to existing DisplayMode and SpeedFormatter.UnitMode types
- No blockers or concerns

## Self-Check: PASSED

- All 9 created files verified on disk
- All 4 task commits verified in git history (72072d9, 081e1c8, 04d8962, 7f14b8a)
- Full test suite passes with zero regressions

---
*Phase: 05-historical-charts-statistics-and-settings*
*Completed: 2026-03-24*
