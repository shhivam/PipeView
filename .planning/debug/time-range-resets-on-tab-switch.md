---
status: awaiting_human_verify
trigger: "time-range-resets-on-tab-switch: selected time range resets to 24H default when switching tabs"
created: 2026-03-25T00:00:00Z
updated: 2026-03-25T00:00:00Z
---

## Current Focus

hypothesis: CONFIRMED -- selectedRange is @State in DashboardView (line 18), and PopoverContentView recreates DashboardView on each tab switch via switch statement (line 24-32), resetting state to .twentyFourHours
test: Move selectedRange to PopoverState (@Observable, persists across tabs) and pass as @Binding to DashboardView
expecting: Time range selection survives tab switches
next_action: Apply fix to PopoverState, PopoverContentView, and DashboardView

## Symptoms

expected: When selecting 1H time range, switching to Preferences tab, then switching back to Dashboard, the 1H selection should be preserved.
actual: The time range resets to 24H (the default) every time the user navigates away from Dashboard and comes back.
errors: No errors -- state management issue where time range selection is not persisted across tab/view changes.
reproduction: 1. Open popover (24H default). 2. Select 1H. 3. Click Preferences tab. 4. Click Dashboard tab. 5. Time range is back to 24H.
started: Likely since the tabbed UI was implemented.

## Eliminated

## Evidence

- timestamp: 2026-03-25T00:01:00Z
  checked: DashboardView.swift line 18
  found: "@State private var selectedRange: HistoryTimeRange = .twentyFourHours" -- local @State, reset on view recreation
  implication: This is the state that gets lost

- timestamp: 2026-03-25T00:01:00Z
  checked: PopoverContentView.swift lines 24-32
  found: "switch popoverState.selectedTab" creates DashboardView inline -- SwiftUI destroys and recreates it on each tab switch
  implication: DashboardView is not kept alive across tab switches, so @State is reset

- timestamp: 2026-03-25T00:01:00Z
  checked: PopoverTab.swift lines 14-17
  found: PopoverState is @Observable class that persists across tab switches (holds selectedTab)
  implication: PopoverState is the right place to hoist selectedRange to -- it already survives tab switches

## Resolution

root_cause: selectedRange is stored as @State in DashboardView. PopoverContentView uses a switch statement to conditionally show DashboardView or PreferencesView, so SwiftUI destroys DashboardView when switching away and recreates it when switching back, resetting @State to the default .twentyFourHours.
fix: Hoist selectedRange into PopoverState (@Observable class that persists across tab switches) and pass it as a @Binding into DashboardView.
verification: Build succeeded. Fix is minimal -- 3 lines changed across 3 files. CodeSign test failure is pre-existing and unrelated.
files_changed: [BandwidthMonitor/Popover/PopoverTab.swift, BandwidthMonitor/Popover/DashboardView.swift, BandwidthMonitor/Popover/PopoverContentView.swift]
