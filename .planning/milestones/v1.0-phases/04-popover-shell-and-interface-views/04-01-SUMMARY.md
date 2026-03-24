---
phase: 04-popover-shell-and-interface-views
plan: 01
subsystem: ui
tags: [swiftui, popover, sf-symbols, accessibility, voiceover]

# Dependency graph
requires:
  - phase: 01-core-monitoring-engine
    provides: "NetworkMonitor (@Observable), Speed, InterfaceSpeed, InterfaceInfo types"
  - phase: 02-menu-bar-display
    provides: "SpeedFormatter for formatting bytes-per-second values"
provides:
  - "PopoverTab enum (.metrics, .preferences) for tab state management"
  - "sfSymbolName(for:) mapping function for interface type to SF Symbol"
  - "PopoverContentView: root popover view with segmented tab switcher, 400x500 frame"
  - "AggregateHeaderView: combined upload/download speed totals"
  - "InterfaceRowView: per-interface row with icon, name, speeds"
  - "MetricsView: aggregate header + scrollable interface list"
  - "PreferencesPlaceholderView: placeholder for Phase 5"
  - "Logger.popover category for popover UI events"
affects: [04-02-PLAN, 05-historical-charts-and-settings]

# Tech tracking
tech-stack:
  added: []
  patterns: ["SwiftUI @Observable direct observation (no @ObservedObject/@StateObject)", "@Binding for cross-component tab state", "sfSymbolName free function for interface icon mapping", "Semantic SwiftUI colors only (zero custom hex)"]

key-files:
  created:
    - BandwidthMonitor/Popover/PopoverTab.swift
    - BandwidthMonitor/Popover/PopoverContentView.swift
    - BandwidthMonitor/Popover/AggregateHeaderView.swift
    - BandwidthMonitor/Popover/InterfaceRowView.swift
    - BandwidthMonitor/Popover/MetricsView.swift
    - BandwidthMonitor/Popover/PreferencesPlaceholderView.swift
  modified:
    - BandwidthMonitor/Logging/Loggers.swift
    - BandwidthMonitor.xcodeproj/project.pbxproj

key-decisions:
  - "Used Color.accentColor instead of .accent for foregroundStyle compatibility with current SwiftUI/Xcode version"
  - "sfSymbolName(for:) as free function (not method on InterfaceInfo) to keep model types clean"

patterns-established:
  - "Semantic colors only: .primary, .secondary, Color.accentColor, Color(.separatorColor) -- no custom hex values"
  - "@Binding var selectedTab pattern for external tab control from StatusBarController"
  - "VoiceOver .accessibilityElement(children: .combine) + .accessibilityLabel for composite views"
  - "monospacedDigit() on all speed value Text views to prevent layout jitter"

requirements-completed: [POP-01, POP-03, POP-05]

# Metrics
duration: 4min
completed: 2026-03-24
---

# Phase 4 Plan 1: Popover Views Summary

**Six SwiftUI popover views with segmented tab switcher, per-interface breakdown, SF Symbol icons, semantic-only colors, and VoiceOver accessibility**

## Performance

- **Duration:** 4 min
- **Started:** 2026-03-23T22:16:57Z
- **Completed:** 2026-03-23T22:21:48Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments
- Created complete popover view layer: PopoverTab enum, PopoverContentView, AggregateHeaderView, InterfaceRowView, MetricsView, PreferencesPlaceholderView
- All views use semantic SwiftUI colors exclusively for automatic dark/light mode adaptation (POP-05)
- VoiceOver accessibility labels on aggregate header sections and interface rows
- Logger.popover category added for future popover lifecycle logging
- 400x500 frame on PopoverContentView matches POP-01 requirement

## Task Commits

Each task was committed atomically:

1. **Task 1: Create PopoverTab enum, SF Symbol mapping, and logger category** - `b778705` (feat)
2. **Task 2: Create all SwiftUI popover views** - `1460c1e` (feat)

## Files Created/Modified
- `BandwidthMonitor/Popover/PopoverTab.swift` - PopoverTab enum (.metrics/.preferences) and sfSymbolName(for:) mapping function
- `BandwidthMonitor/Popover/PopoverContentView.swift` - Root popover view with segmented Picker, @Binding selectedTab, 400x500 frame
- `BandwidthMonitor/Popover/AggregateHeaderView.swift` - Combined upload/download totals with accent-colored arrow SF Symbols
- `BandwidthMonitor/Popover/InterfaceRowView.swift` - Per-interface row: SF Symbol icon + display name + upload/download speeds
- `BandwidthMonitor/Popover/MetricsView.swift` - Composes AggregateHeaderView + Divider + ScrollView of InterfaceRowView rows
- `BandwidthMonitor/Popover/PreferencesPlaceholderView.swift` - Centered "Coming in a future update." placeholder (D-05)
- `BandwidthMonitor/Logging/Loggers.swift` - Added Logger.popover category
- `BandwidthMonitor.xcodeproj/project.pbxproj` - Added all 6 Popover files to BandwidthMonitor target

## Decisions Made
- Used `Color.accentColor` instead of `.accent` for `foregroundStyle` -- `.accent` is not a valid `ShapeStyle` member in the current Swift/SwiftUI version
- `sfSymbolName(for:)` implemented as a free function rather than a method on `InterfaceInfo` to keep model types in the Monitoring layer clean and avoid circular dependencies

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed .accent to Color.accentColor in AggregateHeaderView**
- **Found during:** Task 2 (Create all SwiftUI popover views)
- **Issue:** Plan sample code used `.foregroundStyle(.accent)` but `ShapeStyle` has no `.accent` member
- **Fix:** Changed to `.foregroundStyle(Color.accentColor)` which is the correct SwiftUI API
- **Files modified:** BandwidthMonitor/Popover/AggregateHeaderView.swift
- **Verification:** xcodebuild build succeeded after fix
- **Committed in:** 1460c1e (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Trivial API name correction. No scope change.

## Known Stubs

- `BandwidthMonitor/Popover/PreferencesPlaceholderView.swift` - Intentional placeholder per D-05. Phase 5 will replace with actual preferences controls.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- All popover views are compiled and ready for Plan 02 (StatusBarController integration)
- PopoverContentView accepts `@Binding var selectedTab` for right-click context menu navigation (D-03)
- MetricsView directly observes NetworkMonitor via @Observable -- no additional wiring needed
- PreferencesPlaceholderView ready for Phase 5 replacement

## Self-Check: PASSED

- All 7 files verified present on disk
- Both task commits (b778705, 1460c1e) verified in git log

---
*Phase: 04-popover-shell-and-interface-views*
*Completed: 2026-03-24*
