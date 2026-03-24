---
phase: 04-popover-shell-and-interface-views
verified: 2026-03-24T14:08:00Z
status: human_needed
score: 15/15 automated must-haves verified
re_verification: false
human_verification:
  - test: "Popover opens on left-click and shows live per-interface bandwidth data"
    expected: "Left-clicking the status item opens a ~400x550 popover with a segmented Metrics/Preferences tab switcher. Metrics tab shows aggregate upload/download header with arrow SF Symbols and per-interface rows with SF Symbol icons, display names, and live-updating speeds."
    why_human: "NSPopover rendering and real-time @Observable data flow require a running app."
  - test: "Right-click context menu with Metrics, Preferences, About, Quit items"
    expected: "Right-clicking the status item shows an NSMenu with items: Metrics, History, Preferences, separator, About Bandwidth Monitor, Quit Bandwidth Monitor. Clicking Metrics/Preferences opens popover to that tab. Clicking Quit terminates the app."
    why_human: "NSMenu behavior and tab navigation from context menu items require a running app."
  - test: "Dark and light mode adaptation"
    expected: "Toggling system appearance causes the popover to automatically adapt colors. No custom hex colors -- all semantic SwiftUI colors."
    why_human: "Color rendering under different system appearances requires visual inspection."
---

# Phase 4: Popover Shell and Interface Views Verification Report

**Phase Goal:** Users can click the menu bar item to see a popover window with per-interface bandwidth details, styled correctly for their system appearance
**Verified:** 2026-03-24T14:08:00Z
**Status:** human_needed
**Re-verification:** No -- initial verification

---

## Goal Achievement

### Observable Truths

All truths derived from the PLAN `must_haves` frontmatter across Plans 01 and 02. Success criteria from ROADMAP.md cross-referenced.

#### Plan 01 Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | PopoverTab enum defines .metrics and .preferences cases with raw string values | VERIFIED | `PopoverTab.swift` line 7: `case metrics = "Metrics"`, line 9: `case preferences = "Preferences"`. Phase 5 added `case history = "History"` at line 8 but original .metrics/.preferences cases preserved. Enum conforms to `String, CaseIterable, Sendable` at line 6. |
| 2 | sfSymbolName returns correct SF Symbols for wifi, ethernet, VPN/utun, other | VERIFIED | `PopoverTab.swift` lines 24-38: `func sfSymbolName(for interface: InterfaceInfo) -> String`. Line 26: `interface.bsdName.hasPrefix("utun")` returns `"lock.shield"`. Switch at line 30: `.wifi` returns `"wifi"` (line 32), `.wiredEthernet` returns `"cable.connector.horizontal"` (line 34), `default` returns `"network"` (line 36). utun check precedes switch as required. |
| 3 | PopoverContentView renders a segmented Picker switching tabs | VERIFIED | `PopoverContentView.swift` line 15: `Picker("", selection: $popoverState.selectedTab)` iterating `PopoverTab.allCases`. Line 20: `.pickerStyle(.segmented)`. Switch at line 25 routes `.metrics`, `.history`, `.preferences` to respective views. |
| 4 | AggregateHeaderView shows upload/download with arrow SF Symbols | VERIFIED | `AggregateHeaderView.swift` line 15: `Image(systemName: "arrow.up")` for upload, line 29: `Image(systemName: "arrow.down")` for download. Both use `.foregroundStyle(Color.accentColor)` (lines 17, 32). Speed text uses `.font(.title2.monospacedDigit())` and `.fontWeight(.semibold)` (lines 19-20, 34-35). |
| 5 | InterfaceRowView shows SF Symbol + name + speeds | VERIFIED | `InterfaceRowView.swift` line 13: `Image(systemName: sfSymbolName(for: interfaceSpeed.interface))`. Line 18: `Text(interfaceSpeed.interface.displayName)`. Lines 25-30: upload (`\u{2191}`) and download (`\u{2193}`) speeds formatted via `SpeedFormatter`. Row has `.frame(minHeight: 44)` at line 36. |
| 6 | MetricsView composes AggregateHeaderView + Divider + ScrollView of InterfaceRowView | VERIFIED | `MetricsView.swift` line 13: `AggregateHeaderView(speed: networkMonitor.aggregateSpeed)`. Line 15: `Divider()`. Lines 24-28: `ScrollView { LazyVStack { ForEach(networkMonitor.interfaceSpeeds) { interfaceSpeed in InterfaceRowView(interfaceSpeed: interfaceSpeed) } } }`. Empty state at line 19: `"No active network interfaces detected."`. |
| 7 | All views use only semantic SwiftUI colors | VERIFIED | Grep for hex color patterns (`#[0-9a-fA-F]`, `Color(red:`, `NSColor(red:`) across all `BandwidthMonitor/Popover/*.swift` files returns zero matches. Colors used: `.primary` (AggregateHeaderView lines 21, 36; InterfaceRowView lines 20, 27, 30), `.secondary` (InterfaceRowView line 15; MetricsView line 21), `Color.accentColor` (AggregateHeaderView lines 17, 32). No custom hex values anywhere. |

#### Plan 02 Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 8 | Left-click opens NSPopover | VERIFIED | `StatusBarController.swift` line 52: `button.sendAction(on: [.leftMouseUp, .rightMouseUp])`. Line 108: `statusItemClicked` checks event type. Line 114: else branch calls `togglePopover()`. Line 118-126: `togglePopover()` shows popover via `popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)` at line 124. |
| 9 | Left-click again while open closes it | VERIFIED | `StatusBarController.swift` line 119: `if popover.isShown { popover.performClose(nil) }` -- toggles closed when already showing. |
| 10 | Right-click opens NSMenu with correct items | VERIFIED | `StatusBarController.swift` line 111: `if event.type == .rightMouseUp { showContextMenu() }`. Lines 145-191: `buildContextMenu()` creates NSMenu with items: "Metrics" (line 150), "History" (line 158), "Preferences" (line 166), separator (line 173), "About Bandwidth Monitor" (line 175), "Quit Bandwidth Monitor" (line 183). Menu delegate set at line 147. |
| 11 | Clicking Metrics in context menu opens popover on Metrics tab | VERIFIED | `StatusBarController.swift` lines 195-198: `showMetrics()` sets `popoverState.selectedTab = .metrics` then calls `showPopover()`. |
| 12 | Clicking Preferences opens popover on Preferences tab | VERIFIED | `StatusBarController.swift` lines 205-208: `showPreferences()` sets `popoverState.selectedTab = .preferences` then calls `showPopover()`. |
| 13 | Clicking Quit terminates the app | VERIFIED | `StatusBarController.swift` line 185: `action: #selector(NSApplication.terminate(_:))` on the "Quit Bandwidth Monitor" menu item. |
| 14 | Popover shows live-updating data from NetworkMonitor | VERIFIED | `StatusBarController.swift` lines 17-30: lazy `popover` creates `NSHostingController(rootView: PopoverContentView(networkMonitor: networkMonitor, ...))`. `NetworkMonitor` is `@MainActor @Observable`, so SwiftUI views automatically track property changes. `MetricsView` reads `networkMonitor.aggregateSpeed` and `networkMonitor.interfaceSpeeds` directly. |
| 15 | Popover renders in dark/light mode -- semantic colors only | VERIFIED | All Popover/*.swift files use only semantic SwiftUI colors (`.primary`, `.secondary`, `Color.accentColor`). Zero hex colors, zero custom `NSColor` or `Color(red:green:blue:)` initializers. Automatic dark/light mode adaptation guaranteed by SwiftUI semantic color system. |

**Score:** 15/15 truths verified

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `BandwidthMonitor/Popover/PopoverTab.swift` | `enum PopoverTab` and `func sfSymbolName` | VERIFIED | 39 lines. `enum PopoverTab: String, CaseIterable, Sendable` at line 6 with `.metrics`, `.history`, `.preferences` cases. `func sfSymbolName(for interface: InterfaceInfo) -> String` at line 24. `PopoverState` class at line 16. |
| `BandwidthMonitor/Popover/PopoverContentView.swift` | `struct PopoverContentView: View`, `.frame(width: 400, height: 550)` | VERIFIED | 36 lines. `struct PopoverContentView: View` at line 8. `.frame(width: 400, height: 550)` at line 34. Phase 5 updated from 500 to 550 height. `@Bindable var popoverState: PopoverState` at line 11. |
| `BandwidthMonitor/Popover/AggregateHeaderView.swift` | `struct AggregateHeaderView: View` | VERIFIED | 44 lines. `struct AggregateHeaderView: View` at line 7. `let speed: Speed` at line 8. Arrow SF Symbols with accent color at lines 15-17 and 29-32. |
| `BandwidthMonitor/Popover/InterfaceRowView.swift` | `struct InterfaceRowView: View` | VERIFIED | 40 lines. `struct InterfaceRowView: View` at line 7. `let interfaceSpeed: InterfaceSpeed` at line 8. SF Symbol icon via `sfSymbolName(for:)` at line 13. |
| `BandwidthMonitor/Popover/MetricsView.swift` | `struct MetricsView: View` | VERIFIED | 35 lines. `struct MetricsView: View` at line 8. `let networkMonitor: NetworkMonitor` at line 9. Composes AggregateHeaderView + Divider + ScrollView of InterfaceRowView. |
| `BandwidthMonitor/MenuBar/StatusBarController.swift` | `NSPopover`, `sendAction(on:`, `NSMenuDelegate` | VERIFIED | 223 lines. Class conforms to `NSObject, NSMenuDelegate` at line 7. `lazy var popover: NSPopover` at line 17. `button.sendAction(on: [.leftMouseUp, .rightMouseUp])` at line 52. `func menuDidClose` at line 212 nils `statusItem.menu`. |
| `BandwidthMonitorTests/PopoverTests.swift` | `class PopoverTests: XCTestCase` | VERIFIED | 56 lines. `final class PopoverTests: XCTestCase` at line 5. 10 test methods: 6 SF Symbol mapping tests + 4 PopoverTab tests (metrics, history, preferences rawValue, allCases count). All 10 pass. |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `StatusBarController.swift` | `PopoverContentView.swift` | `NSHostingController(rootView: PopoverContentView(...))` | WIRED | Line 22-27: `NSHostingController(rootView: PopoverContentView(networkMonitor: networkMonitor, appDatabase: appDatabase, popoverState: popoverState))` |
| `StatusBarController.swift` | `NSPopover` | `popover.show(relativeTo:of:preferredEdge:)` | WIRED | Lines 124, 131: `popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)` in both `togglePopover()` and `showPopover()` |
| `StatusBarController.swift` | `NSMenu` | Dynamic `statusItem.menu` assignment + nil-out in `menuDidClose` | WIRED | Line 137: `statusItem.menu = menu` in `showContextMenu()`. Line 214: `statusItem.menu = nil` in `menuDidClose(_:)`. This pattern prevents menu from intercepting subsequent left-clicks. |
| `PopoverContentView.swift` | `NetworkMonitor` | `let networkMonitor: NetworkMonitor` property | WIRED | Line 9: `let networkMonitor: NetworkMonitor`. Passed to `MetricsView(networkMonitor: networkMonitor)` at line 27. |
| `MetricsView.swift` | `NetworkMonitor` | Direct @Observable observation | WIRED | Line 9: `let networkMonitor: NetworkMonitor`. Lines 13, 17, 26: reads `networkMonitor.aggregateSpeed` and `networkMonitor.interfaceSpeeds` directly. SwiftUI tracks @Observable property access automatically. |
| `InterfaceRowView.swift` | `SpeedFormatter` | `format(bytesPerSecond:)` calls | WIRED | Line 9: `private let formatter = SpeedFormatter()`. Lines 25, 29: `formatter.format(bytesPerSecond: ...)` for upload and download speed formatting. |

---

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Build succeeds | `xcodebuild build -scheme BandwidthMonitor -destination 'platform=macOS' -quiet` | Build succeeded, no errors | PASS |
| PopoverTests pass | `xcodebuild test -scheme BandwidthMonitor -only-testing:BandwidthMonitorTests/PopoverTests -quiet` | 10 tests passed, 0 failures (6 SF Symbol mapping + 4 PopoverTab) | PASS |

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| POP-01 | 04-01, 04-02 | Clicking menu bar opens ~400x500 popover | SATISFIED | `PopoverContentView.swift` line 34: `.frame(width: 400, height: 550)`. `StatusBarController.swift` line 19: `popover.contentSize = NSSize(width: 400, height: 550)`. Phase 5 expanded height from 500 to 550 to accommodate History tab. Both views and hosting controller agree on size. |
| POP-03 | 04-01, 04-02 | Per-interface breakdown with individual stats | SATISFIED | `MetricsView.swift` lines 13-32: `AggregateHeaderView` shows combined totals, `ScrollView` with `ForEach(networkMonitor.interfaceSpeeds)` renders `InterfaceRowView` for each active interface. Each row shows SF Symbol icon, display name, and per-direction upload/download speeds. |
| POP-05 | 04-01 | Dark mode and light mode automatic support | SATISFIED | All Popover/*.swift files use only semantic SwiftUI colors: `.primary`, `.secondary`, `Color.accentColor`, `Color(.separatorColor)`. Zero custom hex values found across all popover view files. SwiftUI semantic colors automatically adapt to system appearance. |
| POP-06 | 04-02 | Quit button | SATISFIED | `StatusBarController.swift` line 183-187: "Quit Bandwidth Monitor" item in right-click context menu with `action: #selector(NSApplication.terminate(_:))`. Per D-12 from CONTEXT.md, quit is via context menu rather than inside the popover -- this satisfies the quit accessibility requirement. |

**Orphaned requirements check:** REQUIREMENTS.md maps POP-01, POP-03, POP-05, POP-06 to Phase 4. All four appear in plan frontmatter. No orphaned requirements.

---

### Anti-Patterns Found

| File | Pattern | Severity | Assessment |
|------|---------|----------|------------|
| No files | -- | -- | No TODO/FIXME/HACK/placeholder comments found in any Popover/*.swift file or StatusBarController.swift. `PreferencesPlaceholderView.swift` was deleted by Phase 5 and replaced with full `PreferencesView.swift`. All implementations are complete and substantive. |

---

### Human Verification Required

The following items cannot be verified programmatically. They require running the app and visually inspecting behavior.

#### 1. Popover Opens on Left-Click with Live Data

**Test:** Build and run. Left-click the menu bar item.
**Expected:** A ~400x550 popover appears with a segmented Metrics/History/Preferences tab switcher. Metrics tab (default) shows aggregate upload/download header with accent-colored arrow.up and arrow.down SF Symbols and per-interface rows with SF Symbol icons (wifi, cable, lock.shield, network), display names, and live-updating speeds that refresh every polling cycle.
**Why human:** NSPopover rendering and real-time @Observable data flow require a running app.

#### 2. Right-Click Context Menu Works Correctly

**Test:** Right-click the menu bar item.
**Expected:** An NSMenu appears with items: Metrics, History, Preferences, separator, About Bandwidth Monitor, Quit Bandwidth Monitor. Clicking Metrics opens popover on Metrics tab. Clicking Preferences opens popover on Preferences tab. Clicking Quit terminates the app.
**Why human:** NSMenu behavior and tab navigation from context menu items require a running app.

#### 3. Dark and Light Mode Adaptation

**Test:** Toggle system appearance in System Settings.
**Expected:** The popover automatically adapts colors. All text and icons use semantic SwiftUI colors (.primary, .secondary, Color.accentColor) which respond to system appearance changes without any custom logic.
**Why human:** Color rendering under different system appearances requires visual inspection.

---

### Gaps Summary

No automated gaps found. All 15 truths verified at the code level. All 7 artifacts exist and contain expected content. All 6 key links are wired. Build succeeds. All 10 PopoverTests pass.

The 3 items in Human Verification Required are visual/behavioral outcomes of correctly wired code. They are flagged because the phase goal includes popover rendering, context menu interaction, and appearance adaptation -- none of which can be fully verified without a running macOS session.

---

_Verified: 2026-03-24T14:08:00Z_
_Verifier: Claude (gsd-executor)_
