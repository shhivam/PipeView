---
phase: 05-historical-charts-statistics-and-settings
plan: 03
subsystem: popover-ui, preferences, menu-bar
tags: [swift, swiftui, appstorage, userdefaults, smappservice, preferences, settings]

# Dependency graph
requires:
  - phase: 05-historical-charts-statistics-and-settings
    plan: 01
    provides: "PreferenceKeys, DisplayModePref, UnitModePref, UpdateIntervalPref enums with conversion methods"
  - phase: 05-historical-charts-statistics-and-settings
    plan: 02
    provides: "PopoverContentView with tab routing, StatusBarController with popover/context menu, appDatabase wiring"
provides:
  - "PreferencesView: full settings form with display mode, unit, interval, launch-at-login"
  - "StatusBarController reads display mode and unit from UserDefaults on each observation cycle"
  - "AppDelegate observes update interval changes and applies to NetworkMonitor.pollingInterval"
  - "@Observable PopoverState shared class for reliable tab switching between context menu and SwiftUI"
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "@AppStorage with RawRepresentable enums for type-safe persistent preferences"
    - "UserDefaults.didChangeNotification for cross-component preference observation in AppDelegate"
    - "SMAppService.mainApp for launch-at-login (read status, register/unregister)"
    - "@Observable shared state object (PopoverState) for bridging AppKit context menu actions to SwiftUI view state"

key-files:
  created:
    - BandwidthMonitor/Popover/PreferencesView.swift
  modified:
    - BandwidthMonitor/MenuBar/StatusBarController.swift
    - BandwidthMonitor/AppDelegate.swift
    - BandwidthMonitor/Popover/PopoverContentView.swift
    - BandwidthMonitor/Popover/PopoverTab.swift
    - BandwidthMonitor.xcodeproj/project.pbxproj
  deleted:
    - BandwidthMonitor/Popover/PreferencesPlaceholderView.swift

key-decisions:
  - "UserDefaults.didChangeNotification in AppDelegate rather than per-key KVO for simplicity"
  - "@Observable PopoverState class replaces plain stored property for tab switching (SwiftUI observability)"
  - "SMAppService.mainApp.status read on .onAppear, not @AppStorage (avoids stale cached value)"

patterns-established:
  - "@Observable shared state object pattern for bridging AppKit actions to SwiftUI views"

requirements-completed: [SYS-02]

# Metrics
duration: 5min
completed: 2026-03-24
---

# Phase 5 Plan 3: Preferences UI and Settings Wiring Summary

**Full preferences form with display mode, unit, interval, and launch-at-login settings wired to live menu bar updates via @AppStorage and UserDefaults observation**

## Performance

- **Duration:** 5 min (execution); checkpoint wait time excluded
- **Started:** 2026-03-24T05:53:00Z
- **Completed:** 2026-03-24T06:42:00Z (includes human verification checkpoint)
- **Tasks:** 2
- **Files modified:** 7

## Accomplishments
- Created PreferencesView with grouped Form layout containing Display section (mode + unit pickers) and General section (interval picker + login toggle)
- Wired StatusBarController to read display mode and unit from UserDefaults on every observation cycle, replacing hardcoded defaults
- Connected update interval preference to NetworkMonitor.pollingInterval via UserDefaults.didChangeNotification in AppDelegate
- Fixed tab switching bug by introducing @Observable PopoverState shared between StatusBarController and PopoverContentView
- Deleted PreferencesPlaceholderView -- fully replaced by real implementation
- Human verification confirmed all settings take immediate effect on menu bar display

## Task Commits

Each task was committed atomically:

1. **Task 1: Create PreferencesView and wire StatusBarController + NetworkMonitor** - `9316542` (feat)
2. **Bug fix: @Observable PopoverState for tab switching** - `804b288` (fix)

_Task 2 was a human-verify checkpoint (no code commit)_

## Files Created/Modified
- `BandwidthMonitor/Popover/PreferencesView.swift` - Full preferences form with @AppStorage bindings for display mode, unit, interval; SMAppService toggle for launch-at-login
- `BandwidthMonitor/MenuBar/StatusBarController.swift` - Removed hardcoded displayMode/unitMode; reads from UserDefaults each observation cycle; uses PopoverState for tab switching
- `BandwidthMonitor/AppDelegate.swift` - UserDefaults.didChangeNotification observer updates NetworkMonitor.pollingInterval; initial interval read from preferences
- `BandwidthMonitor/Popover/PopoverContentView.swift` - Routes .preferences to PreferencesView; uses PopoverState for tab binding
- `BandwidthMonitor/Popover/PopoverTab.swift` - Added @Observable PopoverState class
- `BandwidthMonitor.xcodeproj/project.pbxproj` - Added PreferencesView, removed PreferencesPlaceholderView
- `BandwidthMonitor/Popover/PreferencesPlaceholderView.swift` - DELETED (replaced by PreferencesView)

## Decisions Made
- Used UserDefaults.didChangeNotification in AppDelegate (fires on any UserDefaults change) rather than per-key KVO. The overhead is negligible since it only triggers on preference saves, and the handler is a simple integer read + assignment.
- Read SMAppService.mainApp.status on .onAppear rather than caching in @AppStorage. The system is the source of truth for login item state; UserDefaults could become stale if the user changes it in System Settings.
- Created @Observable PopoverState class as shared state between AppKit (StatusBarController context menu) and SwiftUI (PopoverContentView tab picker). Plain stored properties on StatusBarController are not observable by SwiftUI's Binding closures.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Tab switching broken with plain stored property**
- **Found during:** Task 1 (post-commit testing)
- **Issue:** StatusBarController.selectedTab was a plain stored property. The Binding closures passed to PopoverContentView could read/write it, but SwiftUI had no way to observe changes. Clicking context menu items ("Metrics", "History", "Preferences") set the property but the popover UI did not update.
- **Fix:** Introduced @Observable PopoverState class in PopoverTab.swift. StatusBarController creates a PopoverState instance and shares it with PopoverContentView. Context menu actions mutate popoverState.selectedTab, which SwiftUI observes via @Bindable.
- **Files modified:** StatusBarController.swift, PopoverContentView.swift, PopoverTab.swift
- **Verification:** Build succeeds. Context menu tab switching triggers SwiftUI view updates.
- **Committed in:** `804b288`

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Essential fix for tab navigation correctness. No scope creep.

## Issues Encountered

None beyond the deviation documented above.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Phase 5 is now fully complete: all 3 plans delivered (data layer, history tab, preferences)
- All popover tabs functional: Metrics, History, Preferences
- Settings take immediate effect on menu bar display
- This is the final phase in the v1.0 roadmap

## Self-Check: PASSED

- PreferencesView.swift: FOUND on disk
- PreferencesPlaceholderView.swift: CONFIRMED DELETED
- 05-03-SUMMARY.md: FOUND on disk
- Commit 9316542 (feat): FOUND in git history
- Commit 804b288 (fix): FOUND in git history

---
*Phase: 05-historical-charts-statistics-and-settings*
*Completed: 2026-03-24*
