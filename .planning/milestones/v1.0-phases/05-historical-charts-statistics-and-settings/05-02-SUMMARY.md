---
phase: 05-historical-charts-statistics-and-settings
plan: 02
subsystem: popover-ui, charts
tags: [swift, swiftui, swift-charts, bar-chart, history-tab, statistics, popover]

# Dependency graph
requires:
  - phase: 05-historical-charts-statistics-and-settings
    plan: 01
    provides: "ChartDataPoint, HistoryTimeRange, ByteFormatter, AppDatabase.fetchChartData/fetchCumulativeStats"
  - phase: 04-popover-interface-breakdown
    provides: "PopoverContentView, PopoverTab, StatusBarController with popover/context menu"
provides:
  - "HistoryView: tab container with time range picker, chart, and cumulative stats"
  - "HistoryChartView: grouped BarMark chart with download/upload bars and interactive selection tooltip"
  - "StatCardView: combined total with per-direction breakdown display"
  - "CumulativeStatsView: Today, This Week, This Month stats cards"
  - "PopoverTab.history case for tab navigation"
  - "Logger.history category for chart data loading"
affects: [05-03-preferences-ui]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Swift Charts BarMark with grouped position for download/upload direction separation"
    - "chartXSelection with RuleMark annotation for interactive chart tooltips"
    - "Optional AppDatabase parameter for graceful degradation when DB init fails"

key-files:
  created:
    - BandwidthMonitor/Popover/HistoryView.swift
    - BandwidthMonitor/Popover/HistoryChartView.swift
    - BandwidthMonitor/Popover/CumulativeStatsView.swift
    - BandwidthMonitor/Popover/StatCardView.swift
  modified:
    - BandwidthMonitor/Popover/PopoverTab.swift
    - BandwidthMonitor/Popover/PopoverContentView.swift
    - BandwidthMonitor/MenuBar/StatusBarController.swift
    - BandwidthMonitor/AppDelegate.swift
    - BandwidthMonitor/Logging/Loggers.swift
    - BandwidthMonitorTests/PopoverTests.swift
    - BandwidthMonitor.xcodeproj/project.pbxproj

key-decisions:
  - "StatusBarController created after database do-catch block so appDatabase can be passed regardless of DB init success"
  - "AppDatabase optional parameter throughout HistoryView chain -- nil shows empty state gracefully"
  - "Chart colors: Download gets Color.accentColor (prominent), Upload gets Color.secondary.opacity(0.7)"
  - "DateFormatter format varies by time range: h:mm a (1H), h a (24H), MMM d (7D/30D)"

patterns-established:
  - "Interactive Swift Charts with chartXSelection + RuleMark annotation pattern"
  - "Optional dependency injection for database-backed views (graceful degradation)"

requirements-completed: [POP-02, POP-04]

# Metrics
duration: 6min
completed: 2026-03-24
---

# Phase 5 Plan 2: History Tab with Bar Charts and Cumulative Statistics Summary

**History tab with grouped download/upload bar charts via Swift Charts, interactive selection tooltips, and 3 cumulative stats cards (Today/Week/Month)**

## Performance

- **Duration:** 6 min
- **Started:** 2026-03-24T05:46:50Z
- **Completed:** 2026-03-24T05:52:59Z
- **Tasks:** 2
- **Files modified:** 11

## Accomplishments
- Created complete History tab experience: time range picker, grouped bar chart, and cumulative stats
- HistoryChartView renders Swift Charts BarMark with download (accent) and upload (secondary) grouped bars
- Interactive chart selection with tooltip showing formatted timestamp and per-direction byte values
- StatCardView displays combined total with per-direction breakdown, CumulativeStatsView arranges 3 cards
- Updated popover shell: PopoverTab.history, 550px height, StatusBarController passes appDatabase
- Context menu now includes "History" option between Metrics and Preferences
- All existing tests pass with zero regressions; new PopoverTests verify history tab integration

## Task Commits

Each task was committed atomically:

1. **Task 1: Update popover shell and create History tab container** - `6785360` (feat)
2. **Task 2: Create chart and stats card views** - `1160d22` (feat)

## Files Created/Modified
- `BandwidthMonitor/Popover/HistoryView.swift` - History tab container with time range picker, chart data loading, cumulative stats loading
- `BandwidthMonitor/Popover/HistoryChartView.swift` - Swift Charts grouped BarMark chart with selection tooltip and empty state
- `BandwidthMonitor/Popover/CumulativeStatsView.swift` - Horizontal row of 3 StatCardView cards
- `BandwidthMonitor/Popover/StatCardView.swift` - Individual stat card with combined total and direction breakdown
- `BandwidthMonitor/Popover/PopoverTab.swift` - Added .history case
- `BandwidthMonitor/Popover/PopoverContentView.swift` - Routes .history to HistoryView, 550px height, appDatabase parameter
- `BandwidthMonitor/MenuBar/StatusBarController.swift` - appDatabase parameter, 550px popover, History context menu item
- `BandwidthMonitor/AppDelegate.swift` - Passes appDatabase to StatusBarController after DB init
- `BandwidthMonitor/Logging/Loggers.swift` - Added Logger.history category
- `BandwidthMonitorTests/PopoverTests.swift` - Added historyRawValue test, updated allCasesCount to 3
- `BandwidthMonitor.xcodeproj/project.pbxproj` - Added 4 new source files to Xcode project

## Decisions Made
- StatusBarController created after the database do-catch block so it always gets initialized (with or without DB), receiving the optional appDatabase. This prevents the menu bar from being non-functional if DB init fails.
- AppDatabase is optional throughout the HistoryView chain. When nil, HistoryView shows a centered "No data yet" empty state.
- Chart download bars use Color.accentColor for prominence; upload bars use Color.secondary.opacity(0.7) for visual hierarchy.
- Tooltip date formatting adapts to time range: "h:mm a" for 1H, "h a" for 24H, "MMM d" for 7D/30D.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] StatusBarController creation moved outside database do-catch block**
- **Found during:** Task 1 (AppDelegate update)
- **Issue:** Initial edit placed StatusBarController creation inside the do block, meaning if database init failed, no StatusBarController would be created and the entire menu bar UI would be non-functional.
- **Fix:** Moved StatusBarController creation and networkMonitor.start() after the do-catch block so they always execute. appDatabase (which may be nil) is passed as an optional.
- **Files modified:** BandwidthMonitor/AppDelegate.swift
- **Verification:** Build succeeds, both code paths (DB success and failure) result in functioning StatusBarController.
- **Committed in:** 6785360 (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Essential fix for correctness -- prevents app from losing menu bar UI on database failure. No scope creep.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- History tab fully functional with chart rendering and stats display
- Ready for Plan 03 (Preferences UI) -- popover shell supports all 3 tabs
- PreferencesPlaceholderView will be replaced by real Preferences view in Plan 03

## Self-Check: PASSED
