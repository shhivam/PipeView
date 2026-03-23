# Phase 2: Menu Bar Display - Research

**Researched:** 2026-03-23
**Domain:** macOS menu bar UI (NSStatusItem + NSMenu), speed formatting, login item registration
**Confidence:** HIGH

## Summary

Phase 2 transforms the invisible monitoring engine from Phase 1 into a visible, user-facing menu bar application. The core challenge is bridging the `@Observable` `NetworkMonitor` state (running on `@MainActor`) to an AppKit `NSStatusItem` that displays formatted speed text, and converting the current SwiftUI `@main` App stub into a hybrid AppKit+SwiftUI lifecycle.

The technical approach is well-established in the macOS ecosystem. NSStatusItem with `button.attributedTitle` using `NSFont.monospacedDigitSystemFont` is the standard pattern for preventing jitter in frequently-updating text. The `@NSApplicationDelegateAdaptor` property wrapper bridges SwiftUI's App lifecycle to an AppDelegate that owns the NSStatusItem. `SMAppService.mainApp.register()` handles login item registration, though per CONTEXT.md decision D-16, this auto-registers on first launch without explicit user opt-in (note: this may conflict with App Store review guidelines, but is acceptable for direct distribution).

Speed formatting is custom code -- Apple's `ByteCountFormatter` does not support bytes-per-second rates, and the project's specific formatting rules (D-02, D-03, D-09, D-10, D-11) require a purpose-built formatter that handles adaptive precision, SI base-10 boundaries, and fixed-unit ceiling behavior.

**Primary recommendation:** Build a `SpeedFormatter` struct for text formatting, an `AppDelegate` class owning the `NSStatusItem`/`NSMenu`, and bridge `NetworkMonitor` observation via `withObservationTracking` re-registration pattern. Keep all new code in a `MenuBar/` directory alongside the existing `Monitoring/` directory.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Use Unicode arrows (U+2191, U+2193) as upload/download indicators
- **D-02:** Adaptive precision -- 1 decimal place below 100, no decimal at 100+
- **D-03:** Unit labels are MB/s, KB/s, GB/s (base-10 SI byte-rate units, not bits)
- **D-04:** Use SF Pro system font with `.monospacedDigit()` (tabular figures) to prevent jitter
- **D-05:** Text only in menu bar, no app icon. Arrows serve as visual identifier
- **D-06:** Default display mode is "Auto" -- shows whichever direction has higher traffic
- **D-07:** Four display format modes: Auto (default), Upload only, Download only, Both
- **D-08:** "Both" mode format: `up-arrow 1.2 MB/s down-arrow 456 KB/s` (space separator)
- **D-09:** Base-10 SI boundaries: B/s to KB/s at 1,000; KB/s to MB/s at 1,000,000; MB/s to GB/s at 1,000,000,000
- **D-10:** Zero/near-zero (< 1 KB/s) shows "0 KB/s" -- no B/s tier
- **D-11:** Fixed unit selection is a ceiling -- smaller values fall back to smaller units
- **D-12:** Menu items: Metrics (disabled), Preferences (disabled), separator, About, Quit
- **D-13:** Both left-click and right-click open the same NSMenu. No popover in Phase 2
- **D-14:** All user preferences deferred to Phase 5. Phase 2 hardcodes defaults
- **D-15:** Formatting infrastructure supports all modes internally, but no user config in Phase 2
- **D-16:** Auto-register as login item via SMAppService on first launch, no prompt
- **D-17:** First launch goes straight to menu bar -- no onboarding
- **D-18:** When no active interfaces detected, menu bar shows em dash

### Claude's Discretion
- NSMenu construction details and item ordering refinements
- Exact spacing/padding in the status bar text string
- How to bridge NetworkMonitor (@Observable) data to NSStatusItem text updates
- AppDelegate vs SwiftUI App lifecycle integration approach
- SMAppService error handling (if registration fails silently)
- About window content and layout

### Deferred Ideas (OUT OF SCOPE)
- Multi-interface pin (specific interface display) -- Phase 5 preferences
- Display format/unit submenus in right-click menu -- Phase 5 preferences
- Mbps (bits) unit option -- Phase 5 preferences
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| BAR-01 | Menu bar shows current upload and download speed as text | NSStatusItem.button.attributedTitle with SpeedFormatter; NetworkMonitor.aggregateSpeed as data source |
| BAR-02 | User can select preferred display unit (auto-scale, KB/s, MB/s, Gb/s) | SpeedFormatter supports all unit modes internally; hardcoded to auto-scale in Phase 2 (D-14); user config deferred to Phase 5 |
| BAR-03 | User can configure display format (upload+download, download only, upload only, combined total) | DisplayMode enum with four cases; hardcoded to Auto in Phase 2 (D-14); SpeedFormatter handles all formats |
| BAR-04 | Menu bar text uses fixed-width formatting to prevent jitter | NSFont.monospacedDigitSystemFont provides tabular figures; verified as standard solution for this problem |
| SYS-01 | App registers as login item and starts automatically on boot | SMAppService.mainApp.register() on first launch; import ServiceManagement; handle errors silently per discretion |
</phase_requirements>

## Standard Stack

### Core (already in project)
| Technology | Version | Purpose | Why Standard |
|------------|---------|---------|--------------|
| AppKit (NSStatusItem) | macOS 13+ | Menu bar text display, NSMenu | Direct control over status bar button, supports attributedTitle for custom fonts, negligible overhead for frequent updates |
| SwiftUI (@NSApplicationDelegateAdaptor) | macOS 13+ | Bridge SwiftUI App lifecycle to AppDelegate | Apple's supported pattern for hybrid apps; lets us keep @main on the SwiftUI App struct while delegating AppKit setup to AppDelegate |
| ServiceManagement (SMAppService) | macOS 13+ | Login item registration | Apple's modern API replacing deprecated SMLoginItemSetEnabled. SMAppService.mainApp provides direct registration without helper bundles |
| Observation (withObservationTracking) | macOS 14+ / Swift 5.9+ | Bridge @Observable to imperative code | Enables observing NetworkMonitor properties outside SwiftUI views; re-registration pattern provides continuous updates |

### Supporting (already in project via Phase 1)
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| os.Logger | System | Structured logging for menu bar operations | New log category for menu bar events |
| swift-collections | 1.4.1 | Already resolved in SPM | Not needed in Phase 2 directly |

### No New Dependencies Required
Phase 2 requires zero new SPM packages. All functionality is provided by system frameworks (AppKit, ServiceManagement, Observation).

## Architecture Patterns

### Recommended Project Structure
```
BandwidthMonitor/
├── BandwidthMonitorApp.swift   # @main SwiftUI App with @NSApplicationDelegateAdaptor
├── AppDelegate.swift            # NEW: NSStatusItem, NSMenu, lifecycle
├── Info.plist                   # Existing (LSUIElement = YES already set)
├── Logging/
│   └── Loggers.swift            # MODIFY: add .menuBar category
├── MenuBar/                     # NEW: all Phase 2 code
│   ├── StatusBarController.swift  # NSStatusItem + NSMenu management
│   ├── SpeedFormatter.swift       # Speed → formatted string conversion
│   └── SpeedTextBuilder.swift     # Composes display string from Speed + DisplayMode + UnitMode
└── Monitoring/                  # Existing Phase 1 code (unchanged)
    ├── InterfaceDetector.swift
    ├── InterfaceFilter.swift
    ├── NetworkMonitor.swift
    ├── NetworkSample.swift
    ├── SleepWakeHandler.swift
    ├── SpeedComputation.swift
    └── SysctlReader.swift
```

### Pattern 1: Hybrid AppKit+SwiftUI Entry Point
**What:** SwiftUI `@main` App struct delegates AppKit setup to an AppDelegate via `@NSApplicationDelegateAdaptor`.
**When to use:** Always for this project -- per CLAUDE.md architectural decision.
**Example:**
```swift
// Source: Apple Developer Docs + Eclectic Light Company guide
@main
struct BandwidthMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Settings scene is kept so the app has a valid scene;
        // it is never shown since LSUIElement = YES
        Settings {
            EmptyView()
        }
    }
}
```

### Pattern 2: AppDelegate Owning NSStatusItem
**What:** AppDelegate creates and retains NSStatusItem; sets up NSMenu; starts NetworkMonitor.
**When to use:** In `applicationDidFinishLaunching`.
**Example:**
```swift
// Source: Apple docs, polpiella.dev, standard macOS pattern
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let networkMonitor = NetworkMonitor()
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.variableLength
        )
        statusBarController = StatusBarController(
            statusItem: statusItem,
            networkMonitor: networkMonitor
        )
        statusBarController?.setup()
        networkMonitor.start()
        registerLoginItem()
    }
}
```

### Pattern 3: withObservationTracking for Continuous Updates
**What:** Bridge `@Observable` NetworkMonitor to imperative NSStatusItem updates using re-registering observation.
**When to use:** In StatusBarController to observe `aggregateSpeed` changes and update `button.attributedTitle`.
**Example:**
```swift
// Source: polpiella.dev/observable-outside-of-a-view (verified pattern)
// The key insight: withObservationTracking fires only ONCE per registration.
// You must re-register in the onChange callback for continuous updates.
@MainActor
func startObserving() {
    withObservationTracking {
        // Access the properties you want to observe
        let speed = networkMonitor.aggregateSpeed
        let hasInterfaces = !networkMonitor.interfaceSpeeds.isEmpty
        // Update the status item with current values
        updateStatusItemText(speed: speed, hasInterfaces: hasInterfaces)
    } onChange: {
        // Re-register on the next run loop tick (after didSet completes)
        Task { @MainActor [weak self] in
            self?.startObserving()
        }
    }
}
```

### Pattern 4: Attributed String with Monospaced Digits
**What:** Use NSAttributedString with monospacedDigitSystemFont to prevent menu bar jitter.
**When to use:** Every time the status item text is updated.
**Example:**
```swift
// Source: Apple Developer Forums thread 21474, Apple docs
func makeAttributedTitle(_ text: String) -> NSAttributedString {
    let font = NSFont.monospacedDigitSystemFont(
        ofSize: NSFont.systemFontSize, // ~13pt, matches system menu bar
        weight: .regular
    )
    return NSAttributedString(
        string: text,
        attributes: [.font: font]
    )
}
// Usage:
statusItem.button?.attributedTitle = makeAttributedTitle("↑ 1.2 MB/s")
```

### Pattern 5: Custom SpeedFormatter with Decision Rules
**What:** Purpose-built formatter implementing D-02, D-03, D-09, D-10, D-11.
**When to use:** Converting raw `Speed` (bytes/sec) to display text.
**Example:**
```swift
// Custom implementation required -- ByteCountFormatter does NOT support /s rates
struct SpeedFormatter {
    enum UnitMode {
        case auto       // D-09: auto-scale with SI boundaries
        case fixedKB    // Ceiling at KB/s
        case fixedMB    // Ceiling at MB/s
        case fixedGB    // Ceiling at GB/s
    }

    func format(bytesPerSecond: Double, unit: UnitMode = .auto) -> String {
        // D-10: Below 1 KB/s shows "0 KB/s"
        if bytesPerSecond < 1_000 {
            return "0 KB/s"
        }
        // D-09: SI base-10 boundaries
        // D-02: Adaptive precision (1 decimal < 100, no decimal >= 100)
        // D-11: Fixed unit is ceiling, smaller values fall back
        // ...implementation
    }
}
```

### Pattern 6: NSMenu Construction
**What:** Build the right-click/left-click menu per D-12.
**When to use:** During StatusBarController setup.
**Example:**
```swift
func buildMenu() -> NSMenu {
    let menu = NSMenu()

    let metrics = NSMenuItem(title: "Metrics", action: nil, keyEquivalent: "")
    metrics.isEnabled = false  // "Coming soon" per D-12
    menu.addItem(metrics)

    let prefs = NSMenuItem(title: "Preferences", action: nil, keyEquivalent: "")
    prefs.isEnabled = false  // "Coming soon" per D-12
    menu.addItem(prefs)

    menu.addItem(.separator())

    menu.addItem(NSMenuItem(
        title: "About Bandwidth Monitor",
        action: #selector(showAbout),
        keyEquivalent: ""
    ))
    menu.addItem(NSMenuItem(
        title: "Quit Bandwidth Monitor",
        action: #selector(NSApplication.terminate(_:)),
        keyEquivalent: "q"
    ))
    return menu
}
```

### Anti-Patterns to Avoid
- **Using SwiftUI MenuBarExtra for text updates:** Causes unnecessary SwiftUI diffing on every poll cycle. NSStatusItem.button.attributedTitle is a direct property set with zero framework overhead.
- **Using DispatchSourceTimer or Timer for observation:** NetworkMonitor already polls on its own schedule. Do not add a second timer. Instead, observe the `@Observable` properties and react to changes.
- **Storing login item state in UserDefaults:** SMAppService.mainApp.status is the source of truth. Users can toggle login items in System Settings, making any cached state stale.
- **Using ByteCountFormatter for speed text:** Does not support byte rates ("/s" suffix). Appending "/s" breaks localization. Build a custom formatter.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Login item registration | LaunchAgent plist, login item helper bundle | SMAppService.mainApp.register() | Apple's modern API; one line; no helper bundle required; works with App Sandbox |
| Monospaced digit font | Custom font loading, manual character-width adjustment | NSFont.monospacedDigitSystemFont(ofSize:weight:) | System API specifically designed for this; matches system menu bar styling automatically |
| Menu bar item creation | Custom NSView in status bar, NSHostingView for text | NSStatusItem.button.attributedTitle | Direct property on the button; most efficient path; no view hierarchy overhead |
| About window | Custom NSWindow, SwiftUI Window scene | NSApplication.shared.orderFrontStandardAboutPanel(options:) | System-standard About panel; reads Info.plist automatically for app name/version/copyright |
| App agent mode (no dock icon) | NSApplication.setActivationPolicy(.accessory) at runtime | Info.plist LSUIElement = YES | Already set in Phase 1; compile-time configuration; no runtime cost |

**Key insight:** Phase 2 needs surprisingly little custom code. The only significant custom component is SpeedFormatter -- everything else is configuration and wiring of system APIs.

## Common Pitfalls

### Pitfall 1: NSStatusItem Deallocation
**What goes wrong:** The status item disappears from the menu bar immediately after creation.
**Why it happens:** NSStatusItem is not retained by the system. If the variable holding it goes out of scope (e.g., it's a local variable in applicationDidFinishLaunching), ARC deallocates it and it vanishes.
**How to avoid:** Store the NSStatusItem as a strong instance property on AppDelegate or StatusBarController. Never use a local variable.
**Warning signs:** Status item appears briefly then disappears on launch.

### Pitfall 2: withObservationTracking Fires Only Once
**What goes wrong:** Status bar text updates once then never again.
**Why it happens:** `withObservationTracking` only notifies on the FIRST change after registration. It is not a persistent subscription like Combine's `sink`.
**How to avoid:** Re-register the observation inside the `onChange` closure. Use `Task { @MainActor in self?.startObserving() }` to schedule re-registration on the next run loop tick.
**Warning signs:** Menu bar shows the first speed reading then freezes.

### Pitfall 3: onChange Closure Has Old Values
**What goes wrong:** The text displayed is always one update behind.
**Why it happens:** `withObservationTracking`'s onChange fires during `willSet`, meaning the properties still have their OLD values when onChange runs.
**How to avoid:** Do NOT read properties in the onChange closure. Instead, read them in the apply closure (first closure), which runs when you call the function (including when re-registering). The re-registration pattern naturally handles this: re-register triggers apply with NEW values.
**Warning signs:** Speed text lags one poll cycle behind actual values.

### Pitfall 4: SMAppService Registration Without Proper Context
**What goes wrong:** `register()` throws or silently fails; app does not appear in System Settings Login Items.
**Why it happens:** SMAppService requires the app to have a valid bundle identifier and to be running from a proper .app bundle (not Xcode's derived data debug build, in some cases).
**How to avoid:** Wrap `register()` in try/catch and log errors. Check `SMAppService.mainApp.status` after registration. Accept that during development (running from Xcode), login item registration may not work -- this is expected.
**Warning signs:** No login item entry visible in System Settings > General > Login Items.

### Pitfall 5: Menu Bar Text Width Instability
**What goes wrong:** Other menu bar items shift left/right as speed values change.
**Why it happens:** Even with monospacedDigitSystemFont, the total string width changes when the unit changes (KB/s vs MB/s) or when the number of digits changes (9.9 to 10.0 or 99 to 100).
**How to avoid:** The monospacedDigitSystemFont handles digit width. Unit transitions (KB/s to MB/s) are inherently narrow since they happen at clean boundaries. The "Auto" display mode (D-06) helps because it shows only one direction at a time, keeping text shorter. For "Both" mode, accept minor width changes at unit boundaries -- this is a common tradeoff in network monitors.
**Warning signs:** Neighboring menu bar icons (battery, clock) jitter back and forth.

### Pitfall 6: App Store Review and Auto-Registration
**What goes wrong:** App Store rejection because the app auto-registers as login item without user consent.
**Why it happens:** Apple's App Review Guidelines require explicit user consent for auto-launch behavior. D-16 specifies auto-registration on first launch.
**How to avoid:** For direct distribution (outside App Store), D-16 is fine -- macOS shows a system notification when a login item is added, which serves as implicit notification. For App Store distribution, this would need a toggle (deferred to Phase 5). Log this as a known consideration.
**Warning signs:** App Store review rejection citing guideline 2.5.1 or similar.

## Code Examples

### Complete SpeedFormatter Logic (D-02, D-03, D-09, D-10, D-11)
```swift
// Custom implementation -- no Apple API covers byte-rate formatting
struct SpeedFormatter {
    enum UnitMode: Sendable {
        case auto
        case fixedKB   // ceiling: KB/s
        case fixedMB   // ceiling: MB/s
        case fixedGB   // ceiling: GB/s
    }

    /// Format bytes-per-second into a human-readable string.
    /// - D-09: Base-10 SI boundaries (1,000 / 1,000,000 / 1,000,000,000)
    /// - D-02: Adaptive precision (1 decimal < 100, 0 decimals >= 100)
    /// - D-10: Below 1 KB/s shows "0 KB/s"
    /// - D-11: Fixed unit is ceiling; smaller values fall back
    func format(bytesPerSecond: Double, unit: UnitMode = .auto) -> String {
        // D-10: Below 1 KB/s threshold
        guard bytesPerSecond >= 1_000 else {
            return "0 KB/s"
        }

        let (value, suffix) = selectUnit(bytesPerSecond: bytesPerSecond, mode: unit)
        return "\(formatValue(value)) \(suffix)"
    }

    private func selectUnit(bytesPerSecond: Double, mode: UnitMode) -> (Double, String) {
        switch mode {
        case .auto:
            if bytesPerSecond >= 1_000_000_000 {
                return (bytesPerSecond / 1_000_000_000, "GB/s")
            } else if bytesPerSecond >= 1_000_000 {
                return (bytesPerSecond / 1_000_000, "MB/s")
            } else {
                return (bytesPerSecond / 1_000, "KB/s")
            }

        case .fixedGB:
            if bytesPerSecond >= 1_000_000_000 {
                return (bytesPerSecond / 1_000_000_000, "GB/s")
            } else if bytesPerSecond >= 1_000_000 {
                return (bytesPerSecond / 1_000_000, "MB/s")
            } else {
                return (bytesPerSecond / 1_000, "KB/s")
            }

        case .fixedMB:
            // D-11: MB/s is ceiling, fall back for smaller values
            if bytesPerSecond >= 1_000_000 {
                return (bytesPerSecond / 1_000_000, "MB/s")
            } else {
                return (bytesPerSecond / 1_000, "KB/s")
            }

        case .fixedKB:
            return (bytesPerSecond / 1_000, "KB/s")
        }
    }

    /// D-02: Adaptive precision
    /// < 100: 1 decimal place (e.g., "1.2", "45.3")
    /// >= 100: no decimal place (e.g., "456", "1024")
    private func formatValue(_ value: Double) -> String {
        if value < 100 {
            return String(format: "%.1f", value)
        } else {
            return String(format: "%.0f", value)
        }
    }
}
```

### DisplayMode Enum and Speed Text Assembly (D-06, D-07, D-08)
```swift
enum DisplayMode: Sendable {
    case auto          // D-06: show whichever direction has higher traffic
    case uploadOnly
    case downloadOnly
    case both          // D-08: show both with space separator
}

struct SpeedTextBuilder {
    let formatter = SpeedFormatter()

    /// Build the complete menu bar text from a Speed value.
    /// Returns em dash when hasInterfaces is false (D-18).
    func build(
        speed: Speed,
        mode: DisplayMode = .auto,
        unit: SpeedFormatter.UnitMode = .auto,
        hasInterfaces: Bool
    ) -> String {
        // D-18: No active interfaces
        guard hasInterfaces else { return "\u{2014}" } // em dash

        switch mode {
        case .auto:
            // D-06: Show whichever direction has higher traffic
            if speed.bytesOutPerSecond >= speed.bytesInPerSecond {
                return "\u{2191} \(formatter.format(bytesPerSecond: speed.bytesOutPerSecond, unit: unit))"
            } else {
                return "\u{2193} \(formatter.format(bytesPerSecond: speed.bytesInPerSecond, unit: unit))"
            }
        case .uploadOnly:
            return "\u{2191} \(formatter.format(bytesPerSecond: speed.bytesOutPerSecond, unit: unit))"
        case .downloadOnly:
            return "\u{2193} \(formatter.format(bytesPerSecond: speed.bytesInPerSecond, unit: unit))"
        case .both:
            // D-08: Both with space separator
            let up = "\u{2191} \(formatter.format(bytesPerSecond: speed.bytesOutPerSecond, unit: unit))"
            let down = "\u{2193} \(formatter.format(bytesPerSecond: speed.bytesInPerSecond, unit: unit))"
            return "\(up) \(down)"
        }
    }
}
```

### SMAppService Login Item Registration (D-16)
```swift
// Source: Apple Developer Docs, nilcoalescing.com guide
import ServiceManagement

func registerLoginItem() {
    do {
        // D-16: Auto-register on first launch, no prompt
        if SMAppService.mainApp.status != .enabled {
            try SMAppService.mainApp.register()
            Logger.lifecycle.info("Registered as login item successfully")
        }
    } catch {
        // Discretion: fail silently, log for debugging
        Logger.lifecycle.error("Failed to register login item: \(error.localizedDescription)")
    }
}
```

### About Panel (Discretion Area)
```swift
// Source: Apple Developer Documentation orderFrontStandardAboutPanel
@objc func showAbout() {
    // Bring app to front so About panel is visible (agent apps can be behind other windows)
    NSApplication.shared.activate(ignoringOtherApps: true)
    NSApplication.shared.orderFrontStandardAboutPanel(options: [:])
    // The standard About panel reads Info.plist for:
    // - CFBundleName (app name)
    // - CFBundleShortVersionString (version)
    // - NSHumanReadableCopyright (copyright)
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| SMLoginItemSetEnabled (ServiceManagement) | SMAppService.mainApp.register() | macOS 13 (2022) | No helper bundle needed; direct API; status checking |
| ObservableObject + @Published + Combine sink | @Observable + withObservationTracking | Swift 5.9 / macOS 14 (2023) | No Combine import; simpler observation; compile-time tracking |
| NSStatusItem.title (plain text) | NSStatusItem.button.attributedTitle (NSAttributedString) | macOS 10.12+ | Custom fonts, sizing; title property still works but attributedTitle is preferred |
| Manual activation policy code | Info.plist LSUIElement = YES | Always available | Compile-time; no runtime code needed |

**Deprecated/outdated:**
- `NSStatusItem.title`: Still functional but `button?.attributedTitle` is the modern path. Use `attributedTitle` for monospaced digit font.
- `SMLoginItemSetEnabled`: Deprecated since macOS 13. Use SMAppService instead.
- `NSStatusItem.setView(_:)`: Deprecated. Use `button` property instead.

## Open Questions

1. **withObservationTracking re-registration via Task vs RunLoop.current.perform**
   - What we know: Both approaches work for re-registering observation. `Task { @MainActor }` is structured concurrency; `RunLoop.current.perform` is the pattern from polpiella.dev.
   - What's unclear: Whether `Task` adds measurable overhead vs `RunLoop.perform` for updates every 2 seconds.
   - Recommendation: Use `Task { @MainActor }` for consistency with the project's structured concurrency approach. At 2-second intervals, overhead is negligible.

2. **SMAppService behavior in debug builds (running from Xcode)**
   - What we know: SMAppService may not work correctly when the app runs from Xcode's DerivedData path rather than /Applications.
   - What's unclear: Exact failure mode -- does it throw, return .notFound, or silently fail?
   - Recommendation: Wrap in try/catch, log the error, and document that login item registration should be tested with a release build installed in /Applications.

3. **Menu bar font size matching system style**
   - What we know: `NSFont.systemFontSize` returns the standard system font size (~13pt). Menu bar items typically use a slightly smaller size.
   - What's unclear: Whether `systemFontSize` or `NSStatusBar.system.thickness - padding` is the correct size.
   - Recommendation: Start with `NSFont.systemFontSize` for `monospacedDigitSystemFont`. If it looks oversized, try `NSFont.systemFontSize - 1` or experiment with 12pt. The system menu bar clock uses the standard system font size.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode | Build system | Yes | 16.4 (Swift 6.1.2) | -- |
| AppKit (NSStatusItem) | BAR-01, BAR-04 | Yes | System framework | -- |
| ServiceManagement (SMAppService) | SYS-01 | Yes | macOS 13+ (system) | -- |
| Observation framework | NetworkMonitor bridging | Yes | Swift 5.9+ (system) | -- |
| swift-collections | Already resolved in SPM | Yes | 1.4.1 | -- |

**Note on Xcode version:** The installed Xcode is 16.4 with Swift 6.1.2, not the Xcode 26.3 / Swift 6.2 mentioned in CLAUDE.md. The project uses `@Observable` which requires Swift 5.9+, and strict concurrency checking is available in Swift 6.x. All Phase 2 patterns are compatible with Swift 6.1.2.

**Missing dependencies with no fallback:** None.
**Missing dependencies with fallback:** None.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (built into Xcode 16.4) |
| Config file | BandwidthMonitor.xcodeproj (BandwidthMonitorTests target) |
| Quick run command | `xcodebuild test -project BandwidthMonitor.xcodeproj -scheme BandwidthMonitor -only-testing BandwidthMonitorTests -quiet 2>&1 \| tail -20` |
| Full suite command | `xcodebuild test -project BandwidthMonitor.xcodeproj -scheme BandwidthMonitor -quiet` |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| BAR-01 | SpeedFormatter produces correct text for known byte values | unit | `xcodebuild test -scheme BandwidthMonitor -only-testing BandwidthMonitorTests/SpeedFormatterTests -quiet` | No -- Wave 0 |
| BAR-02 | SpeedFormatter handles all UnitMode cases (auto, fixedKB, fixedMB, fixedGB) | unit | `xcodebuild test -scheme BandwidthMonitor -only-testing BandwidthMonitorTests/SpeedFormatterTests -quiet` | No -- Wave 0 |
| BAR-03 | SpeedTextBuilder handles all DisplayMode cases (auto, uploadOnly, downloadOnly, both) | unit | `xcodebuild test -scheme BandwidthMonitor -only-testing BandwidthMonitorTests/SpeedTextBuilderTests -quiet` | No -- Wave 0 |
| BAR-04 | Attributed string uses monospacedDigitSystemFont | unit | `xcodebuild test -scheme BandwidthMonitor -only-testing BandwidthMonitorTests/StatusBarControllerTests -quiet` | No -- Wave 0 |
| SYS-01 | SMAppService.mainApp.register() is called; status checked | manual-only | Manual -- requires installed .app bundle, not Xcode debug build | -- |
| BAR-01 | Em dash shown when no interfaces (D-18) | unit | `xcodebuild test -scheme BandwidthMonitor -only-testing BandwidthMonitorTests/SpeedTextBuilderTests -quiet` | No -- Wave 0 |
| BAR-01 | Zero/near-zero shows "0 KB/s" (D-10) | unit | `xcodebuild test -scheme BandwidthMonitor -only-testing BandwidthMonitorTests/SpeedFormatterTests -quiet` | No -- Wave 0 |
| BAR-03 | Auto mode shows direction with higher traffic (D-06) | unit | `xcodebuild test -scheme BandwidthMonitor -only-testing BandwidthMonitorTests/SpeedTextBuilderTests -quiet` | No -- Wave 0 |

### Sampling Rate
- **Per task commit:** `xcodebuild test -project BandwidthMonitor.xcodeproj -scheme BandwidthMonitor -only-testing BandwidthMonitorTests -quiet 2>&1 | tail -20`
- **Per wave merge:** `xcodebuild test -project BandwidthMonitor.xcodeproj -scheme BandwidthMonitor -quiet`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `BandwidthMonitorTests/SpeedFormatterTests.swift` -- covers BAR-01, BAR-02 (unit formatting, all boundary values, all unit modes)
- [ ] `BandwidthMonitorTests/SpeedTextBuilderTests.swift` -- covers BAR-03, BAR-01 (display modes, em dash for no interfaces, auto mode direction selection)
- [ ] `BandwidthMonitorTests/StatusBarControllerTests.swift` -- covers BAR-04 (verifies attributed string font is monospacedDigit)

## Project Constraints (from CLAUDE.md)

- **Platform:** macOS only, native Swift, no cross-platform frameworks
- **Architecture:** Hybrid AppKit+SwiftUI (~20% AppKit for NSStatusItem shell, ~80% SwiftUI for popover content). Phase 2 is predominantly the AppKit 20%
- **Data storage:** SQLite via GRDB (not relevant to Phase 2)
- **macOS version:** Target macOS 13+ (macOS 14+ for @Observable, which the project already uses)
- **Concurrency:** Swift strict concurrency; use Task.sleep with tolerance, not DispatchSourceTimer
- **Dependencies:** SPM only, no CocoaPods/Carthage
- **Agent app:** LSUIElement = YES in Info.plist (already configured)
- **Network API:** sysctl IFMIB_IFDATA (Phase 1, not modified in Phase 2)
- **Forbidden:** Electron, SwiftData, getifaddrs, NET_RT_IFLIST2, DispatchSourceTimer, CocoaPods/Carthage, ChartsOrg/Charts, nettop
- **Logging:** os.Logger with subsystem from Bundle.main.bundleIdentifier

## Sources

### Primary (HIGH confidence)
- [NSStatusItem - Apple Developer Documentation](https://developer.apple.com/documentation/appkit/nsstatusitem) -- NSStatusItem API, button property, attributedTitle
- [SMAppService - Apple Developer Documentation](https://developer.apple.com/documentation/servicemanagement/smappservice) -- Login item registration API
- [NSFont.monospacedDigitSystemFont - Apple Developer Documentation](https://developer.apple.com/documentation/appkit/nsfont) -- Fixed-width digit font
- [monospacedDigit() - Apple Developer Documentation](https://developer.apple.com/documentation/swiftui/view/monospaceddigit()) -- SwiftUI equivalent (for reference)
- [orderFrontStandardAboutPanel - Apple Developer Documentation](https://developer.apple.com/documentation/appkit/nsapplication/1428724-orderfrontstandardaboutpanel) -- Standard About panel API
- [NSApplicationDelegateAdaptor - Apple Developer Documentation](https://developer.apple.com/documentation/swiftui/nsapplicationdelegateadaptor) -- Hybrid SwiftUI+AppKit bridge

### Secondary (MEDIUM confidence)
- [Using withObservationTracking outside SwiftUI views - polpiella.dev](https://www.polpiella.dev/observable-outside-of-a-view) -- Re-registration pattern for continuous observation; verified working pattern with code examples
- [Add launch at login setting - nilcoalescing.com](https://nilcoalescing.com/blog/LaunchAtLoginSetting/) -- SMAppService practical guide with register/unregister/status checking code
- [SwiftUI on macOS: Life Cycle and AppDelegate - Eclectic Light Company](https://eclecticlight.co/2024/04/17/swiftui-on-macos-life-cycle-and-app-delegate-source-code/) -- @NSApplicationDelegateAdaptor code examples
- [A menu bar only macOS app using AppKit - polpiella.dev](https://www.polpiella.dev/a-menu-bar-only-macos-app-using-appkit/) -- Complete AppDelegate + NSStatusItem setup
- [Monospace Digits - useyourloaf.com](https://useyourloaf.com/blog/monospace-digits/) -- monospacedDigitSystemFont explanation and usage
- [Menu bar set font width - Apple Developer Forums](https://developer.apple.com/forums/thread/21474) -- NSAttributedString with monospacedDigitSystemFont for status bar
- [macOS Service Management - theevilbit.github.io](https://theevilbit.github.io/posts/smappservice/) -- SMAppService technical details, status values
- [Format byte rate - Swift Forums](https://forums.swift.org/t/format-byte-rate/71934) -- Confirmation that ByteCountFormatter does not support byte rates

### Tertiary (LOW confidence)
- [NetSpeedMonitor - GitHub](https://github.com/elegracer/NetSpeedMonitor) -- Open-source macOS network speed menu bar app. Validates architectural approach. Used for general pattern reference only.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- all system frameworks with Apple documentation; no third-party dependencies needed
- Architecture: HIGH -- hybrid AppKit+SwiftUI is a well-documented, standard macOS pattern; @NSApplicationDelegateAdaptor is Apple's official bridge
- Pitfalls: HIGH -- withObservationTracking gotchas verified via official Swift forums and polpiella.dev; NSStatusItem retention is a classic, well-known issue
- Speed formatting: HIGH -- decision rules are explicit and testable; ByteCountFormatter limitation confirmed via Swift Forums
- Login item (SMAppService): MEDIUM -- API is straightforward but debug-build behavior and App Store review implications add uncertainty

**Research date:** 2026-03-23
**Valid until:** 2026-04-23 (stable -- all APIs are mature and unlikely to change)
