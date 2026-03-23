# Phase 4: Popover Shell and Interface Views - Research

**Researched:** 2026-03-24
**Domain:** macOS AppKit NSPopover + SwiftUI hosting, NSStatusItem click handling
**Confidence:** HIGH

## Summary

Phase 4 transforms the menu bar app from a simple status text + NSMenu into a rich interactive tool: left-click opens an NSPopover with SwiftUI content (tabbed Metrics/Preferences view showing per-interface bandwidth), and right-click opens an NSMenu context menu. The core technical challenge is the left-click/right-click split on NSStatusItem -- the current implementation assigns `statusItem.menu` which intercepts all clicks. This must be replaced with a `sendAction(on:)` approach that distinguishes click types and conditionally shows a popover or menu.

The SwiftUI content is straightforward: the existing `NetworkMonitor` is already `@MainActor @Observable`, so SwiftUI views can observe `interfaceSpeeds` and `aggregateSpeed` directly with zero bridging code. The popover is hosted via `NSHostingController` as the `contentViewController` of an `NSPopover`. All styling uses semantic SwiftUI colors (per D-14), and the existing `SpeedFormatter` handles value formatting.

**Primary recommendation:** Refactor `StatusBarController` to own an `NSPopover` (with `NSHostingController<PopoverContentView>` as contentViewController) and an `NSMenu` (for right-click). Remove `statusItem.menu` assignment. Use `button.sendAction(on: [.leftMouseUp, .rightMouseUp])` with an action handler that checks `NSApp.currentEvent?.type` to toggle the popover on left-click or show the menu on right-click.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Left-click on the status item opens the popover window directly. Right-click opens the context menu. This replaces the Phase 2 behavior where both clicks opened NSMenu
- **D-02:** Right-click context menu items: Metrics, Preferences, About Bandwidth Monitor, Quit Bandwidth Monitor
- **D-03:** Clicking "Metrics" or "Preferences" in the right-click menu opens the popover and navigates to that specific tab
- **D-04:** Popover has two tabs: Metrics and Preferences, switched via a segmented control (SwiftUI Picker with .segmented style) at the top
- **D-05:** Preferences tab shows placeholder content in Phase 4 ("Coming in a future update" or similar). Phase 5 fills it in with actual preferences controls
- **D-06:** Metrics is the default tab when opening the popover via left-click
- **D-07:** Simple rows -- each interface is a row with SF Symbol icon + display name on the left, upload and download speeds on the right
- **D-08:** SF Symbols for interface type: wifi for Wi-Fi, cable.connector.horizontal for Ethernet, lock.shield for VPN/utun, network for unknown types
- **D-09:** Popover always shows both upload and download speeds per interface, regardless of menu bar display mode. Menu bar is the summary, popover is the detail
- **D-10:** Aggregate header section at the top of the Metrics tab showing combined total upload/download speed across all interfaces
- **D-11:** Per-interface list below the aggregate header
- **D-12:** No quit button inside the popover -- quit is only available via the right-click context menu. (Deliberate deviation from POP-06 which says "popover includes a visible quit button" -- the right-click menu satisfies the quit accessibility requirement)
- **D-13:** Clean and spacious layout -- generous padding, clear visual hierarchy, breathing room between interface rows
- **D-14:** Purely semantic SwiftUI colors (.primary, .secondary, .accentColor, system backgrounds) -- zero custom colors, automatic dark/light mode adaptation
- **D-15:** Popover size approximately 400x500 pixels per POP-01

### Claude's Discretion
- NSPopover configuration (behavior, appearance, animation)
- How to manage left-click vs right-click on NSStatusItem (NSEvent mask, button override, or popover+menu coexistence)
- Exact spacing, padding, and font sizes within the popover
- How to bridge NetworkMonitor data to SwiftUI views (GRDBQuery @Query, direct @Observable observation, or EnvironmentObject)
- Tab state management (selected tab stored in view vs shared state for menu item navigation)
- Empty state when no interfaces are active (consistent with Phase 2 D-18 em dash approach)
- ScrollView behavior if many interfaces are listed

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| POP-01 | Clicking the menu bar item opens a medium-sized popover window (~400x500px) | NSPopover with contentSize of (400, 500), shown via `show(relativeTo:of:preferredEdge:)` anchored to status item button. Left-click triggers toggle. |
| POP-03 | Popover shows per-interface bandwidth breakdown with individual stats | SwiftUI view observes `NetworkMonitor.interfaceSpeeds` directly (@Observable). Each `InterfaceSpeed` provides `interface.displayName`, `interface.type` (for SF Symbol), and `speed` (for formatting). |
| POP-05 | Popover supports dark mode and light mode automatically | Achieved by using only semantic SwiftUI colors (Color.primary, .secondary, .accentColor, Color(.separatorColor), Color(.controlBackgroundColor)). Zero custom colors = automatic adaptation. |
| POP-06 | Popover includes a quit button | Per D-12: quit button is in the right-click context menu, not inside the popover. The context menu item uses `NSApplication.terminate(_:)`. |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

- **Platform:** macOS only, native Swift, no cross-platform frameworks
- **Architecture:** Hybrid AppKit + SwiftUI (~20% AppKit for NSStatusItem/NSPopover shell, ~80% SwiftUI for popover content)
- **macOS target:** macOS 13+ minimum (for Swift Charts and modern SwiftUI APIs), macOS 14 recommended for @Observable
- **Data observation:** NetworkMonitor is @MainActor @Observable -- SwiftUI views observe directly
- **Styling:** SwiftUI semantic colors only (D-14), SF Pro system font
- **Dependencies:** GRDB.swift 7.10.0, GRDBQuery 0.11.0, swift-collections 1.1+ (already in project)
- **Concurrency:** Swift 6.0 strict concurrency, all model types Sendable, @MainActor for UI-bound state
- **No new dependencies needed** for Phase 4 -- all required frameworks (AppKit, SwiftUI, Network) are Apple first-party

## Standard Stack

### Core (Already in Project)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| AppKit (NSPopover, NSStatusItem) | macOS 13+ | Popover window shell, status item click handling | First-party. NSPopover is the only correct API for menu-bar-anchored floating panels. |
| SwiftUI | macOS 13+ | Popover content views (tabs, interface list, aggregate header) | First-party. Declarative UI with native @Observable integration. |
| SF Symbols | macOS 13+ | Interface type icons (wifi, cable.connector.horizontal, lock.shield, network) | First-party. System-consistent iconography. |
| Network framework | macOS 10.14+ | NWInterface.InterfaceType for SF Symbol mapping | Already used in Phase 1 for InterfaceInfo.type. |

### Supporting (No New Packages)
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| SpeedFormatter | (in-project) | Format bytes/sec to human-readable strings | Reuse for popover speed values (same formatting as menu bar) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| NSPopover | SwiftUI MenuBarExtra(.window) | MenuBarExtra causes performance issues with frequent label updates (per CLAUDE.md). Also lacks right-click menu support. Stick with NSPopover. |
| Direct @Observable observation | EnvironmentObject / GRDBQuery | NetworkMonitor is already @Observable -- direct observation is simpler, no need for EnvironmentObject wrapping or database queries for live data. |
| NSPopover + NSMenu split | Single NSMenu with NSHostingView | Some devs embed SwiftUI in NSMenu via NSHostingView, but this lacks the popover's panel behavior, resize capability, and rich interaction model. NSPopover is correct for this use case. |

## Architecture Patterns

### Recommended Project Structure
```
BandwidthMonitor/
├── MenuBar/
│   ├── StatusBarController.swift    # MODIFIED: add popover + right-click menu
│   ├── SpeedFormatter.swift         # unchanged
│   └── SpeedTextBuilder.swift       # unchanged
├── Popover/                         # NEW directory
│   ├── PopoverContentView.swift     # Root SwiftUI view (tab switcher)
│   ├── MetricsView.swift            # Metrics tab content
│   ├── AggregateHeaderView.swift    # Combined upload/download totals
│   ├── InterfaceRowView.swift       # Single interface row
│   └── PreferencesPlaceholderView.swift  # "Coming in a future update"
├── Monitoring/                      # unchanged
├── Persistence/                     # unchanged
├── Logging/
│   └── Loggers.swift                # ADD: .popover logger category
└── AppDelegate.swift                # MODIFIED: pass NetworkMonitor to popover
```

### Pattern 1: Left-Click / Right-Click Split on NSStatusItem

**What:** Remove `statusItem.menu` assignment. Use `sendAction(on:)` to detect both click types, then branch: left-click toggles NSPopover, right-click shows NSMenu.

**When to use:** Whenever a menu bar app needs different behavior for left vs right click.

**Example:**
```swift
// Source: Community-verified pattern from multiple macOS menu bar app tutorials
// In StatusBarController.setup():

// 1. Do NOT set statusItem.menu -- that intercepts all clicks
// statusItem.menu = buildMenu()  // REMOVE THIS

// 2. Set up button action for both click types
if let button = statusItem.button {
    button.action = #selector(statusItemClicked(_:))
    button.target = self
    button.sendAction(on: [.leftMouseUp, .rightMouseUp])
}

// 3. Action handler distinguishes click type
@objc private func statusItemClicked(_ sender: NSStatusBarButton) {
    guard let event = NSApp.currentEvent else { return }

    if event.type == .rightMouseUp {
        showContextMenu()
    } else {
        togglePopover()
    }
}
```

**Critical detail:** If `statusItem.menu` is set, AppKit intercepts all clicks and shows the menu -- the button's action never fires. You MUST set `statusItem.menu = nil` (or never assign it) to get the button action to work.

### Pattern 2: NSPopover with SwiftUI Content via NSHostingController

**What:** Create an NSPopover, set its contentViewController to an NSHostingController wrapping the root SwiftUI view, then show/hide relative to the status item button.

**When to use:** Any time you need to display SwiftUI content in a popover anchored to a menu bar item.

**Example:**
```swift
// Source: Apple NSPopover documentation + community patterns
private lazy var popover: NSPopover = {
    let popover = NSPopover()
    popover.contentSize = NSSize(width: 400, height: 500)
    popover.behavior = .transient  // closes on click outside
    popover.animates = true
    popover.contentViewController = NSHostingController(
        rootView: PopoverContentView(networkMonitor: networkMonitor)
    )
    return popover
}()

private func togglePopover() {
    if popover.isShown {
        popover.performClose(nil)
    } else if let button = statusItem.button {
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }
}
```

### Pattern 3: Right-Click Context Menu Without Deprecated API

**What:** Show the NSMenu on right-click without using the deprecated `popUpMenu(_:)`. Two approaches: (a) temporarily set `statusItem.menu`, let AppKit show it, then nil it out in `menuDidClose`; or (b) use `NSMenu.popUp(positioning:at:in:)`.

**When to use:** Right-click on status item needs to show a context menu.

**Recommended approach (dynamic menu assignment):**
```swift
// Source: Multiple verified implementations
private func showContextMenu() {
    let menu = buildContextMenu()
    menu.delegate = self  // to nil out after close
    statusItem.menu = menu
    statusItem.button?.performClick(nil)  // triggers AppKit menu display
    // menu is removed in menuDidClose delegate callback
}

// NSMenuDelegate
func menuDidClose(_ menu: NSMenu) {
    statusItem.menu = nil  // restore click handling to button action
}
```

**Why not `popUpMenu(_:)`:** Deprecated since macOS 10.14. While it still works, using the dynamic `statusItem.menu` assignment pattern is forward-compatible and avoids deprecation warnings.

**Why not `NSMenu.popUp(positioning:at:in:)`:** Positioning relative to the status item button is tricky (requires coordinate conversion) and the menu won't look native (won't appear directly below the status item like a real menu bar menu). The dynamic assignment approach gets native positioning for free.

### Pattern 4: Tab Navigation from Context Menu to Popover

**What:** When the user clicks "Metrics" or "Preferences" in the right-click context menu, open the popover and navigate to that specific tab (per D-03).

**When to use:** When external actions need to control SwiftUI view state.

**Example:**
```swift
// Shared state model (can be a simple @Observable class or a property on StatusBarController)
enum PopoverTab: String, CaseIterable {
    case metrics = "Metrics"
    case preferences = "Preferences"
}

// In StatusBarController (or a shared state object):
var selectedTab: PopoverTab = .metrics  // observed by SwiftUI view

// Context menu actions:
@objc private func showMetrics() {
    selectedTab = .metrics
    showPopover()
}

@objc private func showPreferences() {
    selectedTab = .preferences
    showPopover()
}
```

The SwiftUI `PopoverContentView` binds to this shared tab state. Since `StatusBarController` is `@MainActor`, it can hold the tab state directly and pass a `Binding` to the SwiftUI view, or use an intermediary `@Observable` state object.

### Pattern 5: SwiftUI Direct @Observable Observation

**What:** SwiftUI views directly reference `NetworkMonitor` properties. Since `NetworkMonitor` is `@MainActor @Observable`, SwiftUI's observation system automatically tracks changes and re-renders.

**When to use:** For live data display in the popover.

**Example:**
```swift
struct MetricsView: View {
    let networkMonitor: NetworkMonitor

    var body: some View {
        VStack {
            AggregateHeaderView(speed: networkMonitor.aggregateSpeed)
            Divider()
            InterfaceListView(interfaces: networkMonitor.interfaceSpeeds)
        }
    }
}
```

**No `@ObservedObject`, `@StateObject`, or `@EnvironmentObject` needed.** The `@Observable` macro (Swift 5.9+ / macOS 14+) provides automatic tracking. Views just read properties and SwiftUI handles the rest.

**Note on macOS 13 compatibility:** If targeting macOS 13, `@Observable` is not available (it requires macOS 14+). However, the project's STATE.md records a decision: "macOS 14 minimum target for @Observable." The existing codebase already uses `@Observable` on `NetworkMonitor`, confirming macOS 14+ is the actual target.

### Anti-Patterns to Avoid
- **Setting `statusItem.menu` permanently:** This intercepts ALL clicks. You lose the ability to distinguish left from right click. Only set it temporarily during right-click menu display.
- **Using `ObservableObject` + `@Published` when `@Observable` is available:** The project already uses `@Observable` (Swift Observation framework). Don't mix the two systems.
- **Creating a new `NetworkMonitor` instance for the popover:** There is ONE `NetworkMonitor` instance created in `AppDelegate`. Pass the same instance to both `StatusBarController` and the SwiftUI popover views.
- **Embedding complex state in the SwiftUI view hierarchy:** Tab selection that needs to be controlled from outside (context menu) should live in a shared state object, not deep in `@State`.
- **Using `@Environment(\.dismiss)` to close the popover:** The popover is an NSPopover, not a SwiftUI sheet. Closing requires calling `popover.performClose(nil)` on the AppKit side.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Popover window chrome | Custom NSWindow subclass | NSPopover | NSPopover provides the arrow, vibrancy, transient dismiss, and proper anchoring. Custom windows require managing all of this manually. |
| Dark/light mode adaptation | Custom color sets or manual trait observation | Semantic SwiftUI colors (.primary, .secondary, etc.) | System colors adapt automatically. Any custom color logic is fragile and will break with future macOS appearance changes. |
| Speed value formatting | New formatter for popover | Existing SpeedFormatter | Already handles unit selection, adaptive precision, and threshold logic. Reuse it. |
| Interface type to icon mapping | If/else chain or dictionary lookup | Switch on NWInterface.InterfaceType | Type-safe exhaustive switch ensures all cases are handled. Compiler enforces new cases. |
| Click-outside-to-dismiss | NSEvent monitors for global clicks | NSPopover behavior = .transient | Built-in transient behavior handles this correctly, including edge cases like Mission Control and Expose. |

**Key insight:** Phase 4 is almost entirely composition of existing components. The NetworkMonitor data model, SpeedFormatter, and InterfaceInfo types from Phases 1-2 provide all the data. Phase 4 just needs to present them in a new container (NSPopover + SwiftUI views).

## Common Pitfalls

### Pitfall 1: StatusItem.menu Intercepting Left Clicks
**What goes wrong:** After setting `statusItem.menu = buildMenu()`, left-click shows the menu instead of the popover. The button's action handler never fires.
**Why it happens:** AppKit gives `statusItem.menu` priority over `statusItem.button.action`. If menu is set, AppKit shows it on any click.
**How to avoid:** Never permanently assign `statusItem.menu`. Keep it nil by default. Only assign it temporarily when showing the right-click context menu, and nil it out in `menuDidClose(_:)`.
**Warning signs:** Left-click shows a menu instead of the popover. The `statusItemClicked` action handler is never called.

### Pitfall 2: NSPopover Not Closing on Click Outside
**What goes wrong:** User clicks elsewhere on screen but popover stays open.
**Why it happens:** Popover behavior is not set to `.transient`, or the popover's window is not properly configured as a floating panel.
**How to avoid:** Set `popover.behavior = .transient` during initialization. This is the correct behavior for menu bar utility popovers.
**Warning signs:** Popover persists after clicking on the desktop or another window.

### Pitfall 3: SwiftUI View Not Updating When NetworkMonitor Changes
**What goes wrong:** Popover shows stale data even though menu bar text updates correctly.
**Why it happens:** The SwiftUI view doesn't have a reference to the same `NetworkMonitor` instance, or the view is created once and not re-rendered.
**How to avoid:** Pass the `NetworkMonitor` instance to the SwiftUI view. With `@Observable`, SwiftUI automatically tracks property accesses in the `body` computation and re-renders when those properties change. Do NOT create the SwiftUI view only once and cache it -- let NSHostingController manage the view lifecycle.
**Warning signs:** Menu bar text updates every 2 seconds but popover values are frozen.

### Pitfall 4: NSHostingController Root View Updates
**What goes wrong:** Changing the `selectedTab` from the context menu doesn't update the SwiftUI view inside the popover.
**Why it happens:** If tab state is stored on `StatusBarController` (an AppKit class), the SwiftUI view can't observe it unless there's a proper bridging mechanism.
**How to avoid:** Use an `@Observable` state object that both the StatusBarController and the SwiftUI view can reference. Since StatusBarController is `@MainActor`, an inner `@Observable` class works well. Alternatively, update the NSHostingController's rootView directly when tab changes.
**Warning signs:** Clicking "Preferences" in context menu opens the popover but shows Metrics tab.

### Pitfall 5: Memory Leak from NSPopover Retain Cycle
**What goes wrong:** The popover's SwiftUI view holds a strong reference to `NetworkMonitor`, which is owned by `AppDelegate`, which owns `StatusBarController`, which owns the popover.
**Why it happens:** Circular strong reference chain.
**How to avoid:** This is actually fine in this architecture because there's no cycle -- `AppDelegate` owns `NetworkMonitor` AND `StatusBarController`, and the popover's SwiftUI view merely references `NetworkMonitor` (not the other way around). The reference graph is a DAG, not a cycle. Just ensure the popover view doesn't capture `StatusBarController` strongly.
**Warning signs:** Instruments shows the popover's hosting controller is never deallocated even after the popover closes.

### Pitfall 6: Context Menu Items Not Working After Popover Shown
**What goes wrong:** Right-click menu appears but items are grayed out or don't respond.
**Why it happens:** After showing a popover (which becomes key window), the menu's items may not find their targets if `NSApplication.shared` isn't properly activated, or if the target is a different responder chain.
**How to avoid:** Set `target = self` explicitly on all menu items (not relying on responder chain). For "Quit", use `NSApplication.terminate(_:)` which always works. For custom actions, ensure the StatusBarController is the target.
**Warning signs:** Menu items appear but are disabled or clicking them does nothing.

## Code Examples

Verified patterns from official sources and community-standard implementations:

### SF Symbol Mapping for Interface Types
```swift
// Source: D-08 locked decision + NWInterface.InterfaceType API
import Network

extension NWInterface.InterfaceType {
    var sfSymbolName: String {
        switch self {
        case .wifi:
            return "wifi"
        case .wiredEthernet:
            return "cable.connector.horizontal"
        default:
            // VPN tunnels show as .other; utun interfaces detected by BSD name prefix
            return "network"
        }
    }
}

// For VPN detection, check BSD name since NWInterface.InterfaceType
// doesn't have a .vpn case:
func sfSymbolName(for interface: InterfaceInfo) -> String {
    if interface.bsdName.hasPrefix("utun") {
        return "lock.shield"
    }
    return interface.type.sfSymbolName
}
```

### Popover Root View with Segmented Control
```swift
// Source: D-04 (segmented control), D-06 (Metrics default), UI-SPEC
enum PopoverTab: String, CaseIterable {
    case metrics = "Metrics"
    case preferences = "Preferences"
}

struct PopoverContentView: View {
    let networkMonitor: NetworkMonitor
    @Binding var selectedTab: PopoverTab

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                ForEach(PopoverTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 16)

            switch selectedTab {
            case .metrics:
                MetricsView(networkMonitor: networkMonitor)
            case .preferences:
                PreferencesPlaceholderView()
            }
        }
        .frame(width: 400, height: 500)
    }
}
```

### Interface Row View
```swift
// Source: D-07, D-08, D-09, UI-SPEC
struct InterfaceRowView: View {
    let interfaceSpeed: InterfaceSpeed
    private let formatter = SpeedFormatter()

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: sfSymbolName(for: interfaceSpeed.interface))
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .frame(width: 20)

            Text(interfaceSpeed.interface.displayName)
                .font(.body)
                .foregroundStyle(.primary)

            Spacer()

            // Upload and download inline
            HStack(spacing: 12) {
                Text("\u{2191} \(formatter.format(bytesPerSecond: interfaceSpeed.speed.bytesOutPerSecond))")
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.primary)

                Text("\u{2193} \(formatter.format(bytesPerSecond: interfaceSpeed.speed.bytesInPerSecond))")
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.primary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(minHeight: 44)
    }
}
```

### Aggregate Header View
```swift
// Source: D-10, UI-SPEC
struct AggregateHeaderView: View {
    let speed: Speed
    private let formatter = SpeedFormatter()

    var body: some View {
        HStack {
            // Upload total
            HStack(spacing: 4) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 10))
                    .foregroundStyle(.accent)
                Text(formatter.format(bytesPerSecond: speed.bytesOutPerSecond))
                    .font(.title2.monospacedDigit())
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
            }

            Spacer()

            // Download total
            HStack(spacing: 4) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 10))
                    .foregroundStyle(.accent)
                Text(formatter.format(bytesPerSecond: speed.bytesInPerSecond))
                    .font(.title2.monospacedDigit())
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| ObservableObject + @Published | @Observable macro (Observation framework) | WWDC 2023 / macOS 14 | Simpler property access, no property wrappers on observed properties. Already used in this project. |
| statusItem.popUpMenu(_:) | Dynamic statusItem.menu assignment + menuDidClose nil-out | Deprecated macOS 10.14 | Old API still works but generates deprecation warnings. Dynamic approach is forward-compatible. |
| StatusBarController manages NSMenu only | StatusBarController manages NSPopover + NSMenu | Phase 4 | Left-click popover replaces the Phase 2 left-click menu. Right-click menu retains menu items. |
| Separate EnvironmentObject injection | Direct @Observable reference passing | Swift 5.9+ | No need for @EnvironmentObject or @ObservedObject. Pass the @Observable instance directly. |

**Deprecated/outdated:**
- `NSStatusItem.popUpMenu(_:)`: Deprecated macOS 10.14. Use dynamic `statusItem.menu` assignment instead.
- `ObservableObject` / `@Published` / `@ObservedObject`: Superseded by `@Observable` / direct property access for new code targeting macOS 14+.

## Common Accessibility Considerations

Per the UI-SPEC accessibility contract:
- Aggregate speed values need VoiceOver labels: "Upload speed: {value}", "Download speed: {value}"
- Interface rows need combined labels: "{displayName}: upload {value}, download {value}"
- Segmented control gets system-provided accessibility automatically from SwiftUI Picker
- Empty state text is readable by VoiceOver automatically if using standard Text views

Use `.accessibilityLabel()` modifiers on HStack compositions where individual Text elements wouldn't provide coherent screen reader output.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (built into Xcode) |
| Config file | BandwidthMonitorTests target in BandwidthMonitor.xcodeproj |
| Quick run command | `xcodebuild test -project BandwidthMonitor.xcodeproj -scheme BandwidthMonitor -destination 'platform=macOS' -only-testing:BandwidthMonitorTests -quiet` |
| Full suite command | `xcodebuild test -project BandwidthMonitor.xcodeproj -scheme BandwidthMonitor -destination 'platform=macOS' -quiet` |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| POP-01 | Popover opens at ~400x500px | unit | Verify NSPopover contentSize is set correctly | No -- Wave 0 |
| POP-03 | Per-interface breakdown displayed | unit | Verify InterfaceRowView renders with test data, verify MetricsView shows correct number of rows | No -- Wave 0 |
| POP-05 | Dark/light mode support | manual-only | Visual inspection in System Preferences; no custom colors to test programmatically | N/A |
| POP-06 | Quit accessible via context menu | unit | Verify context menu contains "Quit Bandwidth Monitor" item with correct action | No -- Wave 0 |

**Note on UI testing limitations:** SwiftUI views hosted in NSPopover are difficult to unit test in isolation without a running app. The primary testable units are: (1) the SF Symbol mapping function, (2) the context menu construction, (3) the PopoverTab enum and state management, (4) the SpeedFormatter reuse. Visual layout correctness requires manual verification or UI tests.

### Sampling Rate
- **Per task commit:** `xcodebuild test -project BandwidthMonitor.xcodeproj -scheme BandwidthMonitor -destination 'platform=macOS' -only-testing:BandwidthMonitorTests -quiet`
- **Per wave merge:** Full suite (same command)
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `BandwidthMonitorTests/PopoverTests.swift` -- covers POP-01 (contentSize), POP-06 (context menu items), SF Symbol mapping, PopoverTab state
- [ ] No new test fixtures needed -- existing test infrastructure (XCTest, in-memory database) is sufficient
- [ ] No framework install needed -- XCTest is built into Xcode

## Open Questions

1. **NSPopover.behavior = .transient reliability with menu bar apps**
   - What we know: `.transient` closes the popover when the user clicks outside it. This is the standard behavior for menu bar utility popovers.
   - What's unclear: Some developers report edge cases where `.transient` doesn't close the popover during Mission Control or full-screen app transitions. NSPopover's built-in handling is generally correct for these cases on modern macOS.
   - Recommendation: Use `.transient`. If edge cases arise, they can be addressed in a follow-up with an `NSEvent` global monitor, but this is unlikely to be needed.

2. **NSHostingController rootView updates vs recreation**
   - What we know: When `selectedTab` changes from the context menu, the SwiftUI view needs to reflect this. NSHostingController's rootView can be replaced (`hostingController.rootView = newView`) or the view can observe shared state.
   - What's unclear: Whether replacing rootView on an already-visible popover causes visual glitches.
   - Recommendation: Use shared `@Observable` state that both the controller and SwiftUI view reference. This avoids rootView replacement entirely -- the view observes the state object and re-renders when tab changes.

3. **`statusItem.button?.performClick(nil)` for triggering menu display**
   - What we know: After temporarily setting `statusItem.menu`, calling `performClick` on the button triggers AppKit's menu display logic.
   - What's unclear: Whether `performClick` produces an audible click or accessibility notification.
   - Recommendation: This is the most commonly documented approach and is used by established menu bar apps. Test during implementation and switch to `NSMenu.popUp(positioning:at:in:)` only if issues arise.

## Environment Availability

Step 2.6: SKIPPED (no external dependencies identified). Phase 4 uses only Apple first-party frameworks (AppKit, SwiftUI, Network, SF Symbols) already available in the development environment. No CLI tools, databases, or external services needed.

## Sources

### Primary (HIGH confidence)
- Apple Developer Documentation: NSPopover -- behavior property, show(relativeTo:of:preferredEdge:), contentViewController, contentSize
- Apple Developer Documentation: NSStatusItem -- menu property, button property
- Apple Developer Documentation: NSMenu -- delegate protocol, menuDidClose callback
- Apple Developer Documentation: NWInterface.InterfaceType -- case enumeration for SF Symbol mapping
- Existing codebase: NetworkMonitor.swift, StatusBarController.swift, SpeedFormatter.swift, InterfaceInfo model
- Phase 4 UI-SPEC (04-UI-SPEC.md) -- layout contract, spacing, typography, color, interaction contract

### Secondary (MEDIUM confidence)
- [How to support right click menu to NSStatusItem](https://github.com/onmyway133/blog/issues/707) -- sendAction(on:) + NSApp.currentEvent pattern, verified across multiple independent sources
- [NSStatusItem click handling patterns](https://www.polpiella.dev/a-menu-bar-only-macos-app-using-appkit/) -- AppKit menu bar app architecture
- [NSPopover with NSStatusItem](https://shaheengandhi.com/using-nspopover-with-nsstatusitem/) -- Toggle popover pattern, transient behavior
- [Status bar app popover example](https://github.com/innocuo/popover-app/blob/master/popover-app/AppDelegate.swift) -- NSHostingController + NSPopover integration

### Tertiary (LOW confidence)
- None -- all critical patterns verified across multiple sources

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- all frameworks are Apple first-party, already used in prior phases
- Architecture: HIGH -- NSPopover + NSHostingController is the standard pattern for menu bar popovers with SwiftUI content; left/right click split is well-documented across multiple sources
- Pitfalls: HIGH -- pitfalls are well-known in the macOS menu bar app community (especially the statusItem.menu interception issue)
- UI implementation: MEDIUM -- exact SwiftUI layout and spacing will need visual iteration, but the structural approach is sound

**Research date:** 2026-03-24
**Valid until:** 2026-04-24 (stable Apple frameworks, unlikely to change)
