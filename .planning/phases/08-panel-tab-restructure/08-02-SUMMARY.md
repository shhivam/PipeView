---
phase: 08-panel-tab-restructure
plan: 02
subsystem: ui
tags: [appkit, nspanel, floating-window, menu-bar, status-bar]

# Dependency graph
requires:
  - phase: 08-panel-tab-restructure
    plan: 01
    provides: PopoverTab enum (.dashboard/.preferences), DashboardView, PopoverContentView (480x650), PopoverState
provides:
  - FloatingPanel NSPanel subclass (floating, non-activating, dismiss-on-resignKey)
  - StatusBarController migrated from NSPopover to FloatingPanel
  - Panel centering on active screen
  - Updated context menu (Dashboard, Preferences)
affects: [09-chart-fixes-layout-polish]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "NSPanel with .nonactivatingPanel for floating utility windows that dismiss on focus loss"
    - "centerPanelOnActiveScreen() using NSScreen.main?.visibleFrame for centered positioning"
    - "resignKey() override to auto-dismiss panel on click-outside or focus change"

key-files:
  created:
    - BandwidthMonitor/MenuBar/FloatingPanel.swift
  modified:
    - BandwidthMonitor/MenuBar/StatusBarController.swift
    - BandwidthMonitor.xcodeproj/project.pbxproj

key-decisions:
  - "Used NSPanel with .nonactivatingPanel style mask for floating utility window behavior (per RESEARCH.md Pattern 1)"
  - "Panel is non-movable and non-resizable -- fixed centered position for consistent UX"
  - "resignKey() auto-closes panel rather than using NSEvent monitors (simpler, matches NSPanel semantics)"

patterns-established:
  - "FloatingPanel pattern: NSPanel subclass with resignKey() dismiss, no animation, reusable instance"
  - "Hybrid AppKit shell: NSStatusItem + FloatingPanel(NSPanel) hosting SwiftUI via NSHostingView"

requirements-completed: [UIST-02]

# Metrics
duration: 5min
completed: 2026-03-24
---

# Phase 08 Plan 02: Floating Panel Summary

**Replaced NSPopover with floating NSPanel utility window that centers on screen, stays on top, and dismisses on click-outside or focus loss**

## Performance

- **Duration:** 5 min
- **Started:** 2026-03-24T10:15:00Z
- **Completed:** 2026-03-24T13:20:24Z
- **Tasks:** 2 (1 auto + 1 human-verify checkpoint)
- **Files modified:** 3

## Accomplishments
- Created FloatingPanel.swift -- NSPanel subclass with non-activating, floating, dismiss-on-resignKey behavior
- Rewrote StatusBarController to manage FloatingPanel lifecycle instead of NSPopover
- Added centerPanelOnActiveScreen() method for centered panel positioning on the active display
- Panel uses NSHostingView to embed existing SwiftUI PopoverContentView (zero changes to SwiftUI layer)
- Context menu updated: "Dashboard" and "Preferences" items (matching Plan 01 tab restructure)
- Human verified all 9 interactive behaviors: centering, floating, dismiss-on-click-outside, dismiss-on-focus-loss, no animation, context menu items, tab routing, scrolling

## Task Commits

Each task was committed atomically:

1. **Task 1: Create FloatingPanel NSPanel subclass and rewrite StatusBarController** - `35c0a68` (feat)
2. **Task 2: Verify floating panel behavior and combined dashboard view** - checkpoint:human-verify (approved)

**Plan metadata:** (pending -- this commit)

## Files Created/Modified
- `BandwidthMonitor/MenuBar/FloatingPanel.swift` - NSPanel subclass: floating, non-activating, titlebar hidden, dismiss-on-resignKey, no animation, reusable instance
- `BandwidthMonitor/MenuBar/StatusBarController.swift` - Replaced NSPopover with FloatingPanel; added togglePanel(), showPanel(), centerPanelOnActiveScreen(); updated context menu to Dashboard/Preferences
- `BandwidthMonitor.xcodeproj/project.pbxproj` - Added FloatingPanel.swift to Xcode project

## Decisions Made
- Used NSPanel with `.nonactivatingPanel` style mask (per RESEARCH.md Pattern 1) -- provides floating utility window behavior with automatic focus semantics
- Panel is non-movable (`isMovableByWindowBackground = false`) -- fixed centered position for consistent UX across sessions
- Used `resignKey()` override to auto-dismiss panel rather than NSEvent global monitors -- simpler implementation, matches NSPanel's built-in key window semantics
- Panel marked `isReleasedWhenClosed = false` for instance reuse across show/hide cycles

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None - FloatingPanel and StatusBarController migration compiled cleanly on first build. All acceptance criteria passed.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Phase 8 is now complete (both plans done): tab restructure (Plan 01) + floating panel (Plan 02)
- Phase 9 (Chart Fixes & Layout Polish) can begin -- it depends on Phase 8 completion
- The FloatingPanel + DashboardView provide the 480x650 canvas for chart rendering fixes
- MetricsView and HistoryView still exist in codebase (dead code from v1.0; can be cleaned up in a future pass)

## Known Stubs
None - all functionality is fully wired. No placeholder data, hardcoded empty values, or TODO markers.

## Self-Check: PASSED

All created files verified on disk. All commit hashes found in git log.

---
*Phase: 08-panel-tab-restructure*
*Completed: 2026-03-24*
