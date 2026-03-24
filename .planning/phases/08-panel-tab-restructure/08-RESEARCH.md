# Phase 8: Panel & Tab Restructure - Research

**Researched:** 2026-03-24
**Domain:** macOS AppKit window management (NSPanel), SwiftUI view composition
**Confidence:** HIGH

## Summary

This phase replaces the existing `NSPopover` with a floating `NSPanel` (utility window) and merges the separate Metrics and History tabs into a single "Dashboard" view. The technical core is well-understood: NSPanel is Apple's designated class for auxiliary floating windows and is the standard choice for menu bar utility apps. The SwiftUI content composition is straightforward -- the existing `MetricsView` and `HistoryView` are already modular and can be embedded directly into a new combined `DashboardView`.

The main implementation work falls into three areas: (1) subclassing NSPanel with the correct style mask and dismiss-on-focus-loss behavior, (2) replacing all NSPopover usage in StatusBarController with panel show/hide/center logic, and (3) restructuring PopoverContentView and PopoverTab to present the unified Dashboard + Preferences layout. The existing code is cleanly separated -- AppKit shell in StatusBarController, SwiftUI content in Popover/ views -- so the surgery is localized.

**Primary recommendation:** Subclass NSPanel with `[.nonactivatingPanel, .titled, .fullSizeContentView]` style mask, override `resignMain()` to close on focus loss, and use `NSHostingView` to embed the restructured SwiftUI content. Keep the hybrid AppKit+SwiftUI architecture pattern already established in the codebase.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Floating panel appears centered on the active screen, detached from the menu bar (not anchored below the status item)
- **D-02:** Panel dismisses when user clicks outside it or switches focus to another application (same semantic as current `.transient` popover behavior)
- **D-03:** No animation on appear/disappear -- instant show/hide for snappiest feel
- **D-04:** Live speeds at top, history below -- aggregate header + per-interface speeds at top, then time range picker + chart + cumulative stats below (natural reading order: current state then historical context)
- **D-05:** Subtle divider line (SwiftUI `Divider()`) between the live speeds section and the history section
- **D-06:** Entire view scrolls if combined content exceeds panel height -- single `ScrollView` wrapping everything, aggregate header scrolls off-screen if user scrolls down
- **D-07:** Keep 2-tab segmented control: "Dashboard" (combined live + history) and "Preferences"
- **D-08:** Right-click context menu updated to match: "Dashboard" replaces separate "Metrics"/"History" items; "Preferences" stays; "About" and "Quit" unchanged
- **D-09:** Left-click opens panel defaulting to Dashboard tab (same pattern as current `.metrics` default)
- **D-10:** Panel size increased to 480x650 (from current 400x550) to give charts and stat cards more room with the combined content

### Claude's Discretion
- Exact always-on-top window level (NSWindow.Level) for the utility panel
- NSPanel vs NSWindow subclass choice for implementation
- How to center the panel on the active screen (NSScreen.main frame calculation)
- Internal spacing and padding adjustments for the combined view

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| UIST-01 | User sees a single "Metrics" tab combining live interface speeds and history charts in one scrollable view | Architecture Patterns section documents DashboardView composition: MetricsView content + Divider + HistoryView content in a single ScrollView. Existing views are modular and composable. |
| UIST-02 | User interacts with a floating utility panel instead of a popover (stays on top, dismisses on focus loss) | Standard Stack section documents NSPanel subclass pattern with .nonactivatingPanel style mask, .floating level, resignMain() override for dismiss-on-focus-loss. Verified across multiple sources. |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

- **Platform:** macOS only, native Swift, no cross-platform frameworks
- **Architecture:** Hybrid AppKit + SwiftUI -- ~20% AppKit (NSStatusItem, window hosting, app lifecycle), ~80% SwiftUI (all views inside the panel)
- **macOS version:** Target macOS 13+ (for Swift Charts and modern SwiftUI APIs)
- **Data storage:** SQLite via GRDB.swift (unchanged in this phase)
- **Concurrency:** @Observable / @MainActor pattern throughout; Swift 6.2 strict concurrency
- **Dependencies:** SPM only (GRDB 7.10.0, GRDBQuery 0.11.0, swift-collections 1.4.1)
- **Info.plist:** "Application is agent (UIElement)" = YES (no Dock icon)
- **GSD Workflow:** All changes through GSD commands; no direct repo edits

## Standard Stack

### Core (already in project -- no new dependencies)

| Library/Framework | Version | Purpose | Why Standard |
|-------------------|---------|---------|--------------|
| AppKit (NSPanel) | macOS 13+ | Floating utility panel window | Apple's designated class for auxiliary floating windows. Subclass of NSWindow with built-in support for floating behavior, non-activating panels, and auto-hide on deactivation. |
| SwiftUI | macOS 13+ | All view content inside the panel | Already used for all popover content. No change in UI framework. |
| Swift Charts | macOS 13+ | History charts (unchanged) | Already used in HistoryChartView. No changes needed. |

### No New Dependencies

This phase requires zero new package dependencies. NSPanel is part of AppKit (already imported in StatusBarController). All view composition uses existing SwiftUI patterns.

## Architecture Patterns

### Recommended Project Structure Change

```
BandwidthMonitor/
├── MenuBar/
│   ├── StatusBarController.swift     # MODIFY: Replace NSPopover with FloatingPanel
│   ├── FloatingPanel.swift           # NEW: NSPanel subclass
│   ├── SpeedFormatter.swift          # unchanged
│   └── SpeedTextBuilder.swift        # unchanged
├── Popover/                          # (directory name unchanged -- rename is out of scope)
│   ├── PopoverTab.swift              # MODIFY: .metrics/.history -> .dashboard
│   ├── PopoverContentView.swift      # MODIFY: New frame size, switch on dashboard/preferences
│   ├── DashboardView.swift           # NEW: Composed MetricsView + HistoryView content
│   ├── MetricsView.swift             # KEEP (may simplify -- extract body for reuse)
│   ├── HistoryView.swift             # KEEP (may simplify -- extract body for reuse)
│   ├── AggregateHeaderView.swift     # unchanged
│   ├── InterfaceRowView.swift        # unchanged
│   ├── HistoryChartView.swift        # unchanged
│   ├── CumulativeStatsView.swift     # unchanged
│   ├── StatCardView.swift            # unchanged
│   └── PreferencesView.swift         # unchanged
└── ...
```

### Pattern 1: NSPanel Subclass for Floating Utility Window

**What:** Subclass NSPanel to create a floating, non-activating utility window that dismisses on focus loss.

**When to use:** Menu bar apps that need a floating panel instead of an NSPopover.

**Rationale for NSPanel over NSWindow:** NSPanel is Apple's designated class for auxiliary windows. It inherits from NSWindow but adds: `isFloatingPanel` property, `becomesKeyOnlyIfNeeded`, default `hidesOnDeactivate = true` behavior, and support for the `.nonactivatingPanel` style mask. These are exactly what a menu bar utility panel needs.

**Example:**
```swift
// Source: Cindori floating panel pattern + Apple NSPanel documentation
import AppKit

@MainActor
final class FloatingPanel: NSPanel {

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        // Float above other windows
        isFloatingPanel = true
        level = .floating  // NSWindow.Level.floating

        // Don't activate the app when panel appears
        // (menu bar apps should stay "background")

        // Hide title bar chrome
        titleVisibility = .hidden
        titlebarAppearsTransparent = true

        // Hide standard window buttons (close/minimize/zoom)
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true

        // D-03: No animation
        animationBehavior = .none

        // Don't release on close -- we reuse this panel instance
        isReleasedWhenClosed = false

        // Show on all spaces (follows user across desktops)
        collectionBehavior.insert(.fullScreenAuxiliary)
    }

    // Allow the panel to receive keyboard events (for pickers, etc.)
    override var canBecomeKey: Bool { true }

    // Panels should not become main window
    override var canBecomeMain: Bool { false }

    // D-02: Dismiss when user clicks outside / switches focus
    override func resignKey() {
        super.resignKey()
        close()
    }
}
```

**Key design choices:**
- `canBecomeKey = true`: Allows segmented pickers and chart interactions inside the panel to receive keyboard focus.
- `canBecomeMain = false`: Prevents the panel from becoming the main window, which is correct for an auxiliary panel. (NSPanel documentation: "panels may never have main window status.")
- `resignKey()` override for dismiss: When the user clicks outside the panel, the panel resigns key window status. The override closes the panel, achieving the same dismiss-on-click-outside behavior as the current `.transient` NSPopover.
- `isReleasedWhenClosed = false`: The StatusBarController holds a strong reference and reuses the panel instance on each toggle, matching the current lazy NSPopover pattern.
- `.nonactivatingPanel` style mask: Prevents the app from activating when the panel appears, so other apps retain focus until the user explicitly interacts with the panel.
- `animationBehavior = .none`: Per D-03, instant show/hide.

**Window level recommendation:** `.floating` (value 3) is the correct level. This floats above normal windows but below modal panels, screen savers, and the menu bar. Do NOT use `.statusBar` or `.mainMenu` as those can obscure system UI. `.floating` is what Spotlight, Alfred, and similar utility panels use.

### Pattern 2: Panel Centering on Active Screen

**What:** Center the panel on the screen that currently has the mouse cursor (which is the "active" screen from the user's perspective when clicking the menu bar icon).

**Example:**
```swift
// Source: NSScreen documentation + NSWindow.center() behavior
func centerPanelOnActiveScreen() {
    // NSScreen.main returns the screen containing the window that currently
    // receives keyboard events. For a menu bar app with no main window,
    // fall back to the screen with the menu bar (screens.first).
    guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }

    let screenFrame = screen.visibleFrame  // Excludes menu bar and Dock
    let panelSize = panel.frame.size

    let x = screenFrame.origin.x + (screenFrame.width - panelSize.width) / 2
    let y = screenFrame.origin.y + (screenFrame.height - panelSize.height) / 2

    panel.setFrameOrigin(NSPoint(x: x, y: y))
}
```

**Note on `NSWindow.center()`:** Apple's built-in `center()` method centers on the screen associated with the window, but for a newly created/reused panel that may not have a screen association yet, manual calculation using `NSScreen.main` is more reliable. Using `visibleFrame` avoids placing the panel behind the menu bar or Dock.

### Pattern 3: DashboardView Composition (Combined Live + History)

**What:** A new SwiftUI view that composes the existing MetricsView and HistoryView content into a single scrollable dashboard.

**When to use:** D-04 requires live speeds at top, history below, with D-05 divider and D-06 single ScrollView.

**Example:**
```swift
struct DashboardView: View {
    let networkMonitor: NetworkMonitor
    let appDatabase: AppDatabase?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Top section: Live speeds (from MetricsView)
                AggregateHeaderView(speed: networkMonitor.aggregateSpeed)

                Divider()
                    .padding(.horizontal, 16)

                if !networkMonitor.interfaceSpeeds.isEmpty {
                    LazyVStack(spacing: 4) {
                        ForEach(networkMonitor.interfaceSpeeds) { interfaceSpeed in
                            InterfaceRowView(interfaceSpeed: interfaceSpeed)
                        }
                    }
                    .padding(.top, 8)
                } else {
                    Text("No active network interfaces detected.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 16)
                }

                // D-05: Subtle divider between live speeds and history
                Divider()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                // Bottom section: History (from HistoryView)
                // Time range picker + chart + cumulative stats
                // (Inline the HistoryView content or use HistoryView directly)
                HistoryContentSection(appDatabase: appDatabase)
            }
        }
    }
}
```

**Important implementation detail:** The current `MetricsView` has its own internal `ScrollView`. When composing into a single `ScrollView` per D-06, the MetricsView's internal scroll must be removed. The cleanest approach is to either:
1. Extract the MetricsView body content (without its ScrollView) into the DashboardView directly, OR
2. Create a new `DashboardView` that inlines the components from both views.

Option 2 is cleaner because it avoids modifying MetricsView (which might still be used standalone elsewhere, though currently it is not).

### Pattern 4: StatusBarController Panel Management

**What:** Replace the NSPopover lifecycle with NSPanel show/hide/toggle.

**Current pattern (NSPopover):**
```swift
private lazy var popover: NSPopover = { ... }()

private func togglePopover() {
    if popover.isShown {
        popover.performClose(nil)
    } else if let button = statusItem.button {
        popoverState.selectedTab = .metrics
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }
}
```

**New pattern (NSPanel):**
```swift
private lazy var panel: FloatingPanel = {
    let panel = FloatingPanel(contentRect: NSRect(x: 0, y: 0, width: 480, height: 650))
    panel.contentView = NSHostingView(
        rootView: PopoverContentView(
            networkMonitor: networkMonitor,
            appDatabase: appDatabase,
            popoverState: popoverState
        )
    )
    return panel
}()

private func togglePanel() {
    if panel.isVisible {
        panel.close()
    } else {
        popoverState.selectedTab = .dashboard  // D-09
        centerPanelOnActiveScreen()
        panel.makeKeyAndOrderFront(nil)
    }
}

private func showPanel() {
    guard !panel.isVisible else { return }
    centerPanelOnActiveScreen()
    panel.makeKeyAndOrderFront(nil)
}
```

### Anti-Patterns to Avoid

- **Using `hidesOnDeactivate = true` alone for dismiss behavior:** This hides the panel when the entire *application* becomes inactive, which is different from "click outside the panel." For a menu bar agent app (UIElement = YES), the app may already be inactive. Use `resignKey()` override instead, which fires when the panel loses key window status (i.e., user clicks elsewhere).
- **Using `NSWindow` instead of `NSPanel`:** NSWindow does not support the `.nonactivatingPanel` style mask. NSPanel inherits from NSWindow and adds the panel-specific behaviors needed for utility windows.
- **Nesting ScrollViews:** If DashboardView wraps everything in a ScrollView but MetricsView or HistoryView also contain internal ScrollViews, the user gets janky nested scrolling. Remove inner ScrollViews.
- **Using `isMovableByWindowBackground = true`:** Per D-01, the panel appears centered and should not be draggable (the current popover is not draggable). Keeping this false prevents user confusion about window placement.
- **Using `.utilityWindow` in styleMask:** This adds a narrow title bar with a small title. Since we hide the title bar entirely (`titlebarAppearsTransparent = true`, `titleVisibility = .hidden`), `.utilityWindow` adds nothing and can cause visual artifacts.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Floating window above other windows | Custom NSWindow with manual level management | NSPanel with `.nonactivatingPanel` + `isFloatingPanel = true` | NSPanel handles key window semantics, non-activation, and floating behavior correctly. NSWindow + nonactivatingPanel is documented as unsupported. |
| Dismiss on click outside | NSEvent global monitor for mouse clicks | `resignKey()` override in NSPanel subclass | The window server already tracks key window changes. Global event monitors are fragile, CPU-wasteful, and can miss edge cases (spaces, fullscreen apps). |
| Window centering | Manual frame arithmetic without screen awareness | `NSScreen.main?.visibleFrame` + centering calculation | `NSScreen.main` correctly identifies the screen with current keyboard focus. `visibleFrame` accounts for menu bar and Dock insets. |

## Common Pitfalls

### Pitfall 1: Panel Not Receiving Keyboard Events

**What goes wrong:** Segmented pickers, chart interactions, or scroll gestures inside the panel don't respond.
**Why it happens:** `canBecomeKey` defaults to `false` for some NSPanel configurations, especially with `.nonactivatingPanel`.
**How to avoid:** Override `canBecomeKey` to return `true` in the NSPanel subclass.
**Warning signs:** Clicks on pickers/buttons inside the panel are ignored; scroll wheel doesn't work.

### Pitfall 2: Panel Reappears Unexpectedly After Close

**What goes wrong:** The panel flickers or shows again after `close()` is called.
**Why it happens:** `isReleasedWhenClosed` defaults to `true` for NSPanel. If you hold a strong reference and try to show a released panel, behavior is undefined. Also, if `hidesOnDeactivate` is true and the app activates again, the panel may unhide.
**How to avoid:** Set `isReleasedWhenClosed = false`. Do not set `hidesOnDeactivate = true` since we manage visibility via `resignKey()` override instead.
**Warning signs:** Crash on second toggle; panel appears when clicking the menu bar icon even when `togglePanel()` was not called.

### Pitfall 3: Nested ScrollView Conflicts

**What goes wrong:** The dashboard has two scroll regions that fight for scroll events, causing janky behavior.
**Why it happens:** MetricsView currently has its own `ScrollView` for the interface list. If DashboardView wraps everything in another `ScrollView`, the two conflict.
**How to avoid:** Remove the inner `ScrollView` from the metrics section when composing into DashboardView. Use a single outer `ScrollView` per D-06.
**Warning signs:** Some areas of the view scroll while others are stuck; unexpected bounce behavior.

### Pitfall 4: Panel Appears Behind Other Windows

**What goes wrong:** The panel opens but is hidden behind other application windows.
**Why it happens:** `level` was not set to `.floating`, or `isFloatingPanel` was not set to `true`.
**How to avoid:** Set both `level = .floating` and `isFloatingPanel = true` in the panel initializer.
**Warning signs:** Panel opens (verified by logging) but user can't see it; switching to Finder reveals the panel behind it.

### Pitfall 5: HistoryView Data Not Loading in Combined View

**What goes wrong:** The history chart shows "No data yet" even when the database has records.
**Why it happens:** HistoryView currently uses `.onAppear` to trigger `loadChartData()` and `loadStats()`. If the DashboardView embeds HistoryView content without preserving the `.onAppear` lifecycle, data loading never triggers.
**How to avoid:** Ensure the history section's `.onAppear` and `.onChange(of: selectedRange)` handlers are preserved in the combined view. If inlining the content, move the data-loading logic into the DashboardView or a shared view model.
**Warning signs:** Empty chart, zero values in stat cards, but History tab worked fine before the merge.

### Pitfall 6: PopoverTab.allCases Order Changes Break Segmented Control

**What goes wrong:** The segmented control shows tabs in the wrong order after modifying the enum.
**Why it happens:** `CaseIterable` generates `allCases` in declaration order. If you add `.dashboard` but leave old cases, or reorder, the UI changes.
**How to avoid:** Define the enum with exactly `case dashboard = "Dashboard"` and `case preferences = "Preferences"` in the desired order. Verify the segmented control visually.
**Warning signs:** "Preferences" appears as the first tab; extra ghost segments visible.

### Pitfall 7: Existing PopoverTests Fail After Enum Change

**What goes wrong:** Unit tests that assert `PopoverTab.metrics.rawValue == "Metrics"` or `PopoverTab.allCases.count == 3` fail.
**Why it happens:** The enum cases are being renamed/removed.
**How to avoid:** Update PopoverTests to assert on the new enum values (`.dashboard`, `.preferences`) and new count (2).
**Warning signs:** Test target fails to compile.

## Code Examples

### NSPanel Subclass (Complete)

```swift
// Source: Verified pattern from Cindori, Apple NSPanel docs, community implementations
import AppKit

@MainActor
final class FloatingPanel: NSPanel {

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .floating

        titleVisibility = .hidden
        titlebarAppearsTransparent = true

        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true

        animationBehavior = .none
        isReleasedWhenClosed = false
        isMovableByWindowBackground = false

        collectionBehavior.insert(.fullScreenAuxiliary)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func resignKey() {
        super.resignKey()
        close()
    }
}
```

### Updated PopoverTab Enum

```swift
// Source: Existing PopoverTab.swift, modified per D-07
enum PopoverTab: String, CaseIterable, Sendable {
    case dashboard = "Dashboard"
    case preferences = "Preferences"
}

@MainActor @Observable
final class PopoverState {
    var selectedTab: PopoverTab = .dashboard
}
```

### Panel Toggle in StatusBarController

```swift
// Source: Existing togglePopover() pattern, adapted for NSPanel
private func togglePanel() {
    if panel.isVisible {
        panel.close()
    } else {
        popoverState.selectedTab = .dashboard
        centerPanelOnActiveScreen()
        panel.makeKeyAndOrderFront(nil)
    }
}

private func centerPanelOnActiveScreen() {
    guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
    let screenFrame = screen.visibleFrame
    let panelSize = panel.frame.size
    let x = screenFrame.origin.x + (screenFrame.width - panelSize.width) / 2
    let y = screenFrame.origin.y + (screenFrame.height - panelSize.height) / 2
    panel.setFrameOrigin(NSPoint(x: x, y: y))
}
```

### Updated Context Menu

```swift
// Source: Existing buildContextMenu(), modified per D-08
private func buildContextMenu() -> NSMenu {
    let menu = NSMenu()
    menu.delegate = self

    let dashboard = NSMenuItem(
        title: "Dashboard",
        action: #selector(showDashboard),
        keyEquivalent: ""
    )
    dashboard.target = self
    menu.addItem(dashboard)

    let prefs = NSMenuItem(
        title: "Preferences",
        action: #selector(showPreferences),
        keyEquivalent: ""
    )
    prefs.target = self
    menu.addItem(prefs)

    menu.addItem(.separator())

    let about = NSMenuItem(
        title: "About Bandwidth Monitor",
        action: #selector(showAbout),
        keyEquivalent: ""
    )
    about.target = self
    menu.addItem(about)

    let quit = NSMenuItem(
        title: "Quit Bandwidth Monitor",
        action: #selector(NSApplication.terminate(_:)),
        keyEquivalent: "q"
    )
    menu.addItem(quit)

    return menu
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| NSPopover with .transient behavior | NSPanel subclass with resignKey() dismiss | Ongoing pattern since macOS 10.10+ | NSPanel gives more control over window level, positioning, and dismiss behavior. NSPopover is simpler but limited to anchored positioning. |
| Three tabs (Metrics/History/Preferences) | Two tabs (Dashboard/Preferences) | This phase (v1.1) | Reduces cognitive load; user sees everything at a glance without tab switching. |

## Open Questions

1. **resignKey() vs resignMain() for dismiss behavior**
   - What we know: Both are used in community implementations. `resignKey()` fires when another window becomes key (e.g., user clicks outside). `resignMain()` fires when another window becomes main. For NSPanel with `canBecomeMain = false`, `resignMain()` would never fire.
   - What's unclear: Edge cases with context menus -- when the right-click context menu opens, does the panel briefly resign key? This could cause the panel to close when the user right-clicks the status item.
   - Recommendation: Use `resignKey()` as the primary mechanism. If the context menu interaction causes premature dismissal, add a guard flag (`isShowingContextMenu`) to suppress close during context menu display.

2. **HistoryView data loading in combined context**
   - What we know: HistoryView uses `@State` for chart data and cumulative stats, loaded via `.onAppear`. This works when HistoryView is a standalone tab.
   - What's unclear: When composed inside DashboardView's ScrollView, does `.onAppear` fire at the right time? Lazy loading in ScrollView might delay it.
   - Recommendation: Move data loading to `.task {}` modifier on the DashboardView itself, or keep `.onAppear` on the history section and verify it fires. `.task` is more reliable in ScrollView contexts.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (built into Xcode) |
| Config file | BandwidthMonitor.xcodeproj (test target: BandwidthMonitorTests) |
| Quick run command | `xcodebuild test -project BandwidthMonitor.xcodeproj -scheme BandwidthMonitor -only-testing:BandwidthMonitorTests/PopoverTests -destination 'platform=macOS'` |
| Full suite command | `xcodebuild test -project BandwidthMonitor.xcodeproj -scheme BandwidthMonitor -destination 'platform=macOS'` |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| UIST-01 | Single Dashboard tab with combined live speeds and history | unit (enum values, allCases count) + manual (visual verification) | `xcodebuild test -project BandwidthMonitor.xcodeproj -scheme BandwidthMonitor -only-testing:BandwidthMonitorTests/PopoverTests -destination 'platform=macOS'` | Exists (needs update) |
| UIST-02 | Floating utility panel instead of popover | manual-only (requires GUI interaction: click menu bar, verify panel appears floating, click outside to dismiss) | N/A | N/A |

### Sampling Rate
- **Per task commit:** `xcodebuild test -project BandwidthMonitor.xcodeproj -scheme BandwidthMonitor -only-testing:BandwidthMonitorTests/PopoverTests -destination 'platform=macOS'`
- **Per wave merge:** `xcodebuild test -project BandwidthMonitor.xcodeproj -scheme BandwidthMonitor -destination 'platform=macOS'`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] Update `BandwidthMonitorTests/PopoverTests.swift` -- update PopoverTab assertions for new `.dashboard`/`.preferences` enum values, update allCases count from 3 to 2, remove `.metrics` and `.history` assertions

*(No new test files needed -- existing PopoverTests covers the enum/state layer. UIST-02 floating panel behavior is manual-only since it requires macOS GUI interaction.)*

## Sources

### Primary (HIGH confidence)
- [Apple NSPanel Documentation](https://developer.apple.com/documentation/appkit/nspanel) - NSPanel class reference, panel vs window semantics
- [Apple NSWindow.StyleMask.nonactivatingPanel](https://developer.apple.com/documentation/appkit/nswindow/stylemask-swift.struct/nonactivatingpanel) - Non-activating panel style mask behavior
- [Apple NSWindow.StyleMask.utilityWindow](https://developer.apple.com/documentation/appkit/nswindow/stylemask-swift.struct/utilitywindow) - Utility window style mask
- [Apple hidesOnDeactivate](https://developer.apple.com/documentation/appkit/nswindow/1419777-hidesondeactivate) - Window hide-on-deactivate behavior
- [Apple becomesKeyOnlyIfNeeded](https://developer.apple.com/documentation/appkit/nspanel/1528836-becomeskeyonlyifneeded) - Panel key window behavior
- [Apple NSWindow.center()](https://developer.apple.com/documentation/appkit/nswindow/1419090-center) - Window centering method
- [Apple NSScreen](https://developer.apple.com/documentation/appkit/nsscreen) - Screen geometry for positioning

### Secondary (MEDIUM confidence)
- [Cindori: Make a floating panel in SwiftUI for macOS](https://cindori.com/developer/floating-panel) - Complete FloatingPanel implementation pattern, verified against Apple docs
- [Markus Bodner: Create a Spotlight/Alfred like window on macOS with SwiftUI](https://www.markusbodner.com/til/2021/02/08/create-a-spotlight/alfred-like-window-on-macos-with-swiftui/) - NSPanel subclass pattern for utility windows
- [FloatingPanel.swift Gist (jordibruin)](https://gist.github.com/jordibruin/8ae7b79a1c0ce2c355139f29990d5702) - Community NSPanel implementation
- [CocoaDev: NSPanel](https://cocoadev.github.io/NSPanel/) - NSPanel behavior documentation (key vs main window, auto-hide)

### Tertiary (LOW confidence)
- None -- all findings verified against Apple documentation or multiple community sources.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - NSPanel is Apple's first-party API, well-documented, and the designated pattern for floating utility windows. No new dependencies needed.
- Architecture: HIGH - The existing codebase already uses the hybrid AppKit+SwiftUI pattern. The NSPanel subclass follows the same pattern as the current NSPopover usage. View composition is straightforward given the existing modular components.
- Pitfalls: HIGH - All pitfalls identified from actual implementation patterns and verified against Apple documentation or multiple community sources. The nested ScrollView and data loading lifecycle pitfalls are particularly well-understood.

**Research date:** 2026-03-24
**Valid until:** 2026-04-24 (stable Apple frameworks, no fast-moving dependencies)
