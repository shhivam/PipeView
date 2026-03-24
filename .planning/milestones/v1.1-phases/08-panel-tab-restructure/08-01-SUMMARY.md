---
phase: 08-panel-tab-restructure
plan: 01
subsystem: ui
tags: [swiftui, popover, dashboard, tabs]

# Dependency graph
requires:
  - phase: 05-popover-ui
    provides: PopoverTab enum, MetricsView, HistoryView, PopoverContentView, AggregateHeaderView, InterfaceRowView, CumulativeStatsView, HistoryChartView
provides:
  - DashboardView combining live speeds + history in single ScrollView
  - Updated PopoverTab enum with .dashboard/.preferences cases
  - Updated PopoverContentView with 480x650 frame and 2-tab layout
  - Updated StatusBarController context menu for Dashboard tab
affects: [08-panel-tab-restructure]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Single ScrollView dashboard composing multiple subviews inline (avoids nested ScrollViews)"
    - ".task {} for data loading in ScrollView context (more reliable than .onAppear)"

key-files:
  created:
    - BandwidthMonitor/Popover/DashboardView.swift
    - .gitignore
  modified:
    - BandwidthMonitor/Popover/PopoverTab.swift
    - BandwidthMonitor/Popover/PopoverContentView.swift
    - BandwidthMonitor/MenuBar/StatusBarController.swift
    - BandwidthMonitorTests/PopoverTests.swift
    - BandwidthMonitor.xcodeproj/project.pbxproj

key-decisions:
  - "Inlined MetricsView and HistoryView content into DashboardView instead of embedding them as subviews, avoiding nested ScrollViews"
  - "Used .task {} instead of .onAppear for data loading in ScrollView context per RESEARCH.md recommendation"

patterns-established:
  - "Dashboard composition pattern: inline subview content in single ScrollView with VStack(spacing: 0)"

requirements-completed: [UIST-01]

# Metrics
duration: 4min
completed: 2026-03-24
---

# Phase 08 Plan 01: Tab Restructure Summary

**Merged Metrics + History tabs into single Dashboard tab with ScrollView layout, updated PopoverTab enum to 2 cases, expanded frame to 480x650**

## Performance

- **Duration:** 4 min
- **Started:** 2026-03-24T10:08:50Z
- **Completed:** 2026-03-24T10:13:40Z
- **Tasks:** 2
- **Files modified:** 7

## Accomplishments
- Created DashboardView combining live speeds (AggregateHeaderView + interface list) and history (time range picker + chart + cumulative stats) in a single ScrollView
- Updated PopoverTab enum from 3 cases (.metrics/.history/.preferences) to 2 cases (.dashboard/.preferences)
- Updated PopoverContentView frame from 400x550 to 480x650 per D-10
- Updated StatusBarController context menu to use Dashboard instead of separate Metrics/History items
- All 10 PopoverTests pass (4 updated tab tests + 6 sfSymbolName tests)

## Task Commits

Each task was committed atomically:

1. **Task 1: Update PopoverTab enum and create DashboardView (TDD)** - `759968a` (test: RED), `1ac10c4` (feat: GREEN)

_Note: Task 2 (Update PopoverContentView) was completed as part of Task 1 due to build dependency -- PopoverContentView had to be updated simultaneously with PopoverTab to maintain compilability. No separate commit needed._

**Plan metadata:** (pending)

## Files Created/Modified
- `BandwidthMonitor/Popover/DashboardView.swift` - New combined dashboard view composing live speeds + history in single ScrollView
- `BandwidthMonitor/Popover/PopoverTab.swift` - Updated enum: .dashboard/.preferences (was .metrics/.history/.preferences)
- `BandwidthMonitor/Popover/PopoverContentView.swift` - Updated switch to .dashboard case, frame to 480x650
- `BandwidthMonitor/MenuBar/StatusBarController.swift` - Updated context menu and tab selection to use .dashboard
- `BandwidthMonitorTests/PopoverTests.swift` - Updated tab tests for new enum values
- `BandwidthMonitor.xcodeproj/project.pbxproj` - Added DashboardView.swift to project
- `.gitignore` - Added .DS_Store and xcuserdata exclusions

## Decisions Made
- Inlined MetricsView and HistoryView content into DashboardView instead of embedding them as subviews, to avoid nested ScrollViews (per RESEARCH.md Pitfall 3)
- Used `.task {}` instead of `.onAppear` for data loading in ScrollView context (per RESEARCH.md Open Question 2)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Updated StatusBarController for new tab enum**
- **Found during:** Task 1 (PopoverTab enum update)
- **Issue:** StatusBarController referenced .metrics and .history which no longer exist after enum update
- **Fix:** Replaced showMetrics/showHistory with showDashboard, updated context menu items
- **Files modified:** BandwidthMonitor/MenuBar/StatusBarController.swift
- **Verification:** xcodebuild build succeeds
- **Committed in:** 1ac10c4 (Task 1 GREEN commit)

**2. [Rule 3 - Blocking] Updated PopoverContentView switch statement in Task 1**
- **Found during:** Task 1 (PopoverTab enum update)
- **Issue:** PopoverContentView switch cases referenced .metrics and .history which no longer exist
- **Fix:** Updated switch to .dashboard/.preferences and changed frame to 480x650 (completing Task 2 scope)
- **Files modified:** BandwidthMonitor/Popover/PopoverContentView.swift
- **Verification:** xcodebuild build succeeds, TEST SUCCEEDED
- **Committed in:** 1ac10c4 (Task 1 GREEN commit)

**3. [Rule 2 - Missing Critical] Added .gitignore**
- **Found during:** Task 1 (commit preparation)
- **Issue:** No .gitignore existed; .DS_Store and xcuserdata would be committed
- **Fix:** Created .gitignore with .DS_Store and xcuserdata exclusions
- **Files modified:** .gitignore (created)
- **Verification:** git status no longer shows .DS_Store
- **Committed in:** 1ac10c4 (Task 1 GREEN commit)

---

**Total deviations:** 3 auto-fixed (2 blocking, 1 missing critical)
**Impact on plan:** All auto-fixes necessary for compilation and repo hygiene. Task 2 scope was absorbed into Task 1 due to build dependency. No scope creep.

## Issues Encountered
None - plan executed smoothly after accounting for build dependencies between tasks.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Dashboard tab structure complete, ready for Plan 02 (floating panel migration)
- MetricsView and HistoryView still exist in codebase (can be removed in a cleanup pass if desired)
- StatusBarController context menu simplified from 3 tab items to 1 Dashboard item

## Self-Check: PASSED

All created files verified on disk. All commit hashes found in git log.

---
*Phase: 08-panel-tab-restructure*
*Completed: 2026-03-24*
