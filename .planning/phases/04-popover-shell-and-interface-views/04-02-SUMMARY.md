---
phase: 04-popover-shell-and-interface-views
plan: 02
subsystem: ui
tags: [appkit, nspopover, nsmenu, swiftui, nsstatusitem]

requires:
  - phase: 04-popover-shell-and-interface-views (Plan 01)
    provides: SwiftUI popover views (PopoverContentView, MetricsView, InterfaceRowView, AggregateHeaderView, PopoverTab)
provides:
  - NSPopover wired to StatusBarController with left-click toggle
  - Right-click context menu with Metrics, Preferences, About, Quit
  - Tab navigation from context menu items into popover
  - PopoverTests covering SF Symbol mapping and PopoverTab enum
affects: [05-historical-charts-statistics-and-settings]

tech-stack:
  added: []
  patterns: [left-click popover + right-click menu via sendAction(on:), lazy NSPopover with NSHostingController, menuDidClose nil-out pattern]

key-files:
  created:
    - BandwidthMonitorTests/PopoverTests.swift
  modified:
    - BandwidthMonitor/MenuBar/StatusBarController.swift

key-decisions:
  - "Left-click/right-click split via button.sendAction(on: [.leftMouseUp, .rightMouseUp]) — avoids intercepting all clicks with statusItem.menu"
  - "menuDidClose nils statusItem.menu to restore left-click popover after context menu closes (Pitfall 1 from research)"
  - "selectedTab stored on StatusBarController, passed to PopoverContentView via Binding closures — enables context menu to drive tab selection"
  - "updatePopoverRootView() replaces NSHostingController rootView before showing to sync Binding closures"

patterns-established:
  - "NSPopover + NSMenu coexistence: assign menu only on right-click, nil in menuDidClose"
  - "Tab state bridging: AppKit property → SwiftUI Binding via get/set closures"

requirements-completed: [POP-01, POP-03, POP-05, POP-06]

duration: 4min
completed: 2026-03-24
---

# Phase 4, Plan 02: Popover + Context Menu Wiring Summary

**StatusBarController refactored for left-click NSPopover with live per-interface data and right-click context menu with Metrics/Preferences/About/Quit**

## Performance

- **Duration:** ~4 min
- **Completed:** 2026-03-24
- **Tasks:** 3 (2 auto + 1 human-verify checkpoint)
- **Files modified:** 2 (+ 1 created)

## Accomplishments
- Refactored StatusBarController to replace permanent NSMenu with left-click popover / right-click context menu split
- NSPopover hosts PopoverContentView with live NetworkMonitor data via @Observable
- Context menu items (Metrics, Preferences) navigate to specific popover tabs via selectedTab binding
- 9 unit tests passing: SF Symbol mapping (wifi, ethernet, VPN, other, loopback) and PopoverTab enum validation

## Task Commits

1. **Task 1: Refactor StatusBarController for popover + context menu** - `d464b6f` (feat)
2. **Task 2: Unit tests for SF Symbol mapping and PopoverTab** - `5f7fc13` (test)
3. **Task 3: Human verification checkpoint** - approved by user

## Files Created/Modified
- `BandwidthMonitor/MenuBar/StatusBarController.swift` - Added NSPopover, left/right click handling, context menu, NSMenuDelegate
- `BandwidthMonitorTests/PopoverTests.swift` - 9 tests for sfSymbolName and PopoverTab

## Decisions Made
- Used lazy NSPopover with NSHostingController to defer popover creation until first use
- Context menu built fresh on each right-click (not cached) — simple and avoids stale state
- About menu item uses standard NSApplication.orderFrontStandardAboutPanel

## Deviations from Plan
None - plan executed as written

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Popover shell complete with two tabs (Metrics, Preferences placeholder)
- Phase 5 adds History tab, replaces Preferences placeholder, and wires user settings
- StatusBarController ready for Phase 5: preferences will update hardcoded displayMode/unitMode

---
*Phase: 04-popover-shell-and-interface-views*
*Completed: 2026-03-24*
