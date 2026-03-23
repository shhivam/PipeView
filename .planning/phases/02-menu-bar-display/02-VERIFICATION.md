---
phase: 02-menu-bar-display
verified: 2026-03-24T00:00:00Z
status: gaps_found
score: 3/5 must-haves verified
re_verification: false
gaps:
  - truth: "User can change display units (auto-scale, KB/s, MB/s, Gb/s) and the menu bar text updates accordingly"
    status: failed
    reason: "displayMode and unitMode are hardcoded let constants in StatusBarController. No user-facing UI or preferences storage exists. The formatting infrastructure (SpeedFormatter.UnitMode enum with all 4 cases) is fully implemented, but there is no way for a user to change the setting — it is locked to .auto."
    artifacts:
      - path: "BandwidthMonitor/MenuBar/StatusBarController.swift"
        issue: "Line 14: `private let unitMode: SpeedFormatter.UnitMode = .auto` — immutable constant, no persistence or user control"
    missing:
      - "User-facing unit preference selector (Preferences UI or menu submenu)"
      - "Persistence of unit preference (UserDefaults or AppStorage)"
      - "StatusBarController must read unitMode from persisted preference, not a hardcoded constant"
  - truth: "User can switch display format between upload+download, download only, upload only, or combined total"
    status: failed
    reason: "displayMode is hardcoded to .auto in StatusBarController. No user-facing UI exists to switch format. The DisplayMode enum with all 4 cases is fully implemented in SpeedTextBuilder, but there is no path for a user to select a different mode."
    artifacts:
      - path: "BandwidthMonitor/MenuBar/StatusBarController.swift"
        issue: "Line 14: `private let displayMode: DisplayMode = .auto` — immutable constant, no persistence or user control"
    missing:
      - "User-facing format preference selector (Preferences UI or menu submenu)"
      - "Persistence of display format preference"
      - "StatusBarController must read displayMode from persisted preference, not a hardcoded constant"
human_verification:
  - test: "Confirm the menu bar speed text updates in real time"
    expected: "Text changes every ~2 seconds to reflect current network traffic"
    why_human: "Cannot verify live update behavior without running the app"
  - test: "Confirm em dash appears on first launch before first poll completes"
    expected: "Menu bar shows — for ~2 seconds before the first speed reading"
    why_human: "Timing-dependent; requires visual inspection during launch"
  - test: "Confirm SMAppService login item registration succeeds on a signed build from /Applications"
    expected: "App appears in System Settings > General > Login Items after first launch"
    why_human: "SMAppService.mainApp.register() is expected to fail silently in Xcode debug builds; requires a notarized or Developer ID signed build installed to /Applications"
---

# Phase 2: Menu Bar Display Verification Report

**Phase Goal:** Users can see their current network speeds at a glance in the macOS menu bar, formatted to their preference, every time their Mac starts
**Verified:** 2026-03-24
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Menu bar shows current upload/download speeds as text that updates in real time | VERIFIED | StatusBarController.startObserving() uses withObservationTracking re-registration pattern reading networkMonitor.aggregateSpeed; SpeedTextBuilder.build() composes directional arrow strings |
| 2 | User can change display units (auto-scale, KB/s, MB/s, Gb/s) and menu bar text updates accordingly | FAILED | `unitMode` is `private let unitMode: SpeedFormatter.UnitMode = .auto` — immutable constant. No preference UI or persistence. Explicitly deferred to Phase 5 per D-14/D-15 in CONTEXT.md. |
| 3 | User can switch display format between upload+download, download only, upload only, or combined total | FAILED | `displayMode` is `private let displayMode: DisplayMode = .auto` — immutable constant. No preference UI or persistence. Explicitly deferred to Phase 5 per D-14/D-15 in CONTEXT.md. |
| 4 | Menu bar text does not jitter or cause neighboring menu bar items to shift when values change | VERIFIED | StatusBarController.updateStatusItemText() uses NSFont.monospacedDigitSystemFont(ofSize:weight:) and sets NSAttributedString on attributedTitle (line 65-72) |
| 5 | The app starts automatically when macOS boots without requiring manual launch | VERIFIED | AppDelegate.registerLoginItem() calls SMAppService.mainApp.register() with status guard; fails silently in debug builds as expected |

**Score:** 3/5 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `BandwidthMonitor/MenuBar/SpeedFormatter.swift` | Speed formatting with SI units, adaptive precision, unit modes | VERIFIED | 53 lines. Contains `struct SpeedFormatter`, `enum UnitMode` with 4 cases, `func format(bytesPerSecond:unit:)`, private `selectUnit` and `formatValue` helpers. Substantive implementation. Registered in Xcode main target. |
| `BandwidthMonitor/MenuBar/SpeedTextBuilder.swift` | Display string composition from Speed + DisplayMode + UnitMode | VERIFIED | 49 lines. Contains `enum DisplayMode` with 4 cases, `struct SpeedTextBuilder`, `func build(speed:mode:unit:hasInterfaces:)`. Fully implemented with all D-06/D-07/D-08/D-18 logic. Registered in Xcode main target. |
| `BandwidthMonitorTests/SpeedFormatterTests.swift` | Unit tests for all formatting rules | VERIFIED | 96 lines, 20 test methods covering all boundary values (D-10 threshold, D-02 adaptive precision, D-09 SI boundaries, D-11 ceiling modes). Exceeds 40-line minimum. |
| `BandwidthMonitorTests/SpeedTextBuilderTests.swift` | Unit tests for all display modes and edge cases | VERIFIED | 79 lines, 11 test methods covering D-06 (auto mode tie-breaking), D-07 (upload/download only), D-08 (both mode), D-18 (no interfaces in all 4 modes). Exceeds 40-line minimum. |
| `BandwidthMonitor/MenuBar/StatusBarController.swift` | NSStatusItem management, NSMenu, observation bridge to NetworkMonitor | VERIFIED | 114 lines. Contains `class StatusBarController: NSObject`, withObservationTracking observation bridge, monospacedDigitSystemFont, 5-item NSMenu (Metrics disabled, Preferences disabled, separator, About, Quit), em dash initial state. Registered in Xcode main target. |
| `BandwidthMonitor/AppDelegate.swift` | Application lifecycle, owns StatusBarController + NetworkMonitor, registers login item | VERIFIED | 56 lines. Contains `class AppDelegate: NSObject, NSApplicationDelegate`, strong NSStatusItem reference, NetworkMonitor ownership, StatusBarController instantiation, SMAppService.mainApp.register() with status guard. |
| `BandwidthMonitor/BandwidthMonitorApp.swift` | Hybrid AppKit+SwiftUI entry point with @NSApplicationDelegateAdaptor | VERIFIED | 12 lines. Contains `@NSApplicationDelegateAdaptor(AppDelegate.self)`, `Settings { EmptyView() }` scene. No legacy `Text("Bandwidth Monitor")` placeholder. |
| `BandwidthMonitor/Logging/Loggers.swift` | Logger categories including menuBar | VERIFIED | Contains `static let menuBar = Logger(subsystem: subsystem, category: "menuBar")` added at line 17. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| SpeedTextBuilder.swift | SpeedFormatter.swift | SpeedTextBuilder uses SpeedFormatter.format() | WIRED | `formatter.format(bytesPerSecond:unit:)` called at lines 32, 34, 38, 41, 44, 45 |
| SpeedTextBuilder.swift | NetworkSample.swift (Speed struct) | SpeedTextBuilder consumes Speed struct | WIRED | `speed.bytesOutPerSecond` and `speed.bytesInPerSecond` referenced at lines 31, 32, 34, 38, 41, 44, 45 |
| StatusBarController.swift | NetworkMonitor.swift | withObservationTracking re-registration pattern | WIRED | `withObservationTracking` at line 42; reads `networkMonitor.aggregateSpeed` and `networkMonitor.interfaceSpeeds` |
| StatusBarController.swift | SpeedTextBuilder.swift | SpeedTextBuilder.build() to format speed | WIRED | `textBuilder.build(speed:mode:unit:hasInterfaces:)` at line 46 |
| StatusBarController.swift | NSStatusItem.button.attributedTitle | NSAttributedString with monospacedDigitSystemFont | WIRED | `statusItem.button?.attributedTitle = NSAttributedString(...)` at lines 69-72 |
| AppDelegate.swift | StatusBarController.swift | AppDelegate creates and retains StatusBarController | WIRED | `statusBarController = StatusBarController(statusItem: statusItem, networkMonitor: networkMonitor)` at lines 22-25 |
| AppDelegate.swift | SMAppService.mainApp.register() | Login item registration in applicationDidFinishLaunching | WIRED | `SMAppService.mainApp.register()` at line 46, guarded by status check at line 45 |
| BandwidthMonitorApp.swift | AppDelegate.swift | @NSApplicationDelegateAdaptor bridges SwiftUI App to AppDelegate | WIRED | `@NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate` at line 5 |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| StatusBarController.swift | `aggregateSpeed` | NetworkMonitor.aggregateSpeed (read inside withObservationTracking apply closure) | Yes — Phase 1 NetworkMonitor computes this from sysctl reads | FLOWING |
| StatusBarController.swift | `hasInterfaces` | `!networkMonitor.interfaceSpeeds.isEmpty` (read inside withObservationTracking apply closure) | Yes — Phase 1 NetworkMonitor populates interfaceSpeeds from InterfaceDetector | FLOWING |

### Behavioral Spot-Checks

Step 7b skipped — requires running the app (macOS GUI application; no runnable entry points accessible without Xcode build and launch). Human verification covers this.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| BAR-01 | 02-01, 02-02 | Menu bar shows current upload and download speed as text | SATISFIED | SpeedTextBuilder composes directional arrow strings; StatusBarController renders via NSAttributedString with real NetworkMonitor data |
| BAR-02 | 02-01 (claimed) | User can select preferred display unit in preferences | PARTIAL — INFRASTRUCTURE ONLY | SpeedFormatter.UnitMode enum with all 4 cases exists and works. No user-facing preferences UI or persistence. unitMode is hardcoded .auto. Per D-14, preferences deferred to Phase 5. |
| BAR-03 | 02-01 (claimed) | User can configure display format in preferences | PARTIAL — INFRASTRUCTURE ONLY | DisplayMode enum with all 4 cases exists and works. No user-facing preferences UI or persistence. displayMode is hardcoded .auto. Per D-14, preferences deferred to Phase 5. |
| BAR-04 | 02-02 | Menu bar text uses fixed-width formatting to prevent jitter | SATISFIED | NSFont.monospacedDigitSystemFont + NSAttributedString.attributedTitle in StatusBarController |
| SYS-01 | 02-02 | App registers as a login item and starts automatically on macOS boot | SATISFIED (conditional) | SMAppService.mainApp.register() implemented with status guard; expected to fail in debug builds, requires signed build from /Applications for full verification |

**Note on BAR-02 and BAR-03:** The plan summaries mark these as `requirements-completed: [BAR-01, BAR-02, BAR-03]` and `requirements-completed: [BAR-04, SYS-01]`, but REQUIREMENTS.md still shows all five as "Pending." This reflects the architectural gap: the formatting infrastructure exists but the user-accessible control path (preferences + persistence) does not. The ROADMAP Success Criteria 2 and 3 are not fulfilled at this phase.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| StatusBarController.swift | 14 | `private let displayMode: DisplayMode = .auto` | Info | Intentional stub per D-14/D-15; formattig infrastructure ready but locked to defaults |
| StatusBarController.swift | 15 | `private let unitMode: SpeedFormatter.UnitMode = .auto` | Info | Same — intentional deferral to Phase 5 |
| StatusBarController.swift | 84 | `"Preferences"` menu item with `action: nil, isEnabled = false` | Info | Intentional placeholder per D-12 ("Coming soon"); unblocks Phase 5 |
| StatusBarController.swift | 80 | `"Metrics"` menu item with `action: nil, isEnabled = false` | Info | Intentional placeholder per D-12 ("Coming soon"); unblocks Phase 4 |

No fatalError stubs, no return null/empty, no TODO/FIXME/HACK comments found in production files. All anti-patterns are intentional stubs documented in CONTEXT.md.

### Human Verification Required

#### 1. Live Speed Text Update

**Test:** Build and run from Xcode. Observe the macOS menu bar top-right area.
**Expected:** An em dash appears within ~1 second of launch, then within ~2 seconds updates to a speed reading like "up-arrow 0 KB/s" or "down-arrow 1.2 MB/s". Text updates every ~2 seconds thereafter.
**Why human:** Cannot verify live NSStatusItem text rendering and timing without launching the macOS app.

#### 2. Context Menu Structure

**Test:** Left-click and right-click the menu bar speed text.
**Expected:** Both clicks open the same NSMenu with exactly 5 items in order: "Metrics" (grayed out), "Preferences" (grayed out), a separator line, "About Bandwidth Monitor" (enabled), "Quit Bandwidth Monitor" (enabled with Cmd+Q shortcut).
**Why human:** Cannot verify NSMenu rendering and click behavior programmatically.

#### 3. Login Item Registration (Signed Build)

**Test:** Install a Developer ID signed build to /Applications and launch it once.
**Expected:** App appears in System Settings > General > Login Items after first launch. On reboot, the app starts automatically.
**Why human:** SMAppService.mainApp.register() is expected to fail silently in Xcode debug builds per RESEARCH.md Pitfall 4. Requires a signed, installed build. Cannot be automated without a full release build pipeline.

### Gaps Summary

Two of the five ROADMAP Success Criteria are not met by Phase 2's implementation. Both are caused by the same root cause: user preferences (unit selection and display format) were explicitly deferred to Phase 5 per decision D-14 in CONTEXT.md.

**Root cause:** The formatting infrastructure (SpeedFormatter.UnitMode, DisplayMode enums with all cases) is complete and tested. However, StatusBarController hardcodes `displayMode = .auto` and `unitMode = .auto` as `let` constants. There is no:
- Preferences window or preferences menu action
- UserDefaults/AppStorage persistence for these settings
- Way for the user to change either setting at runtime

The ROADMAP explicitly states Success Criteria 2 and 3 as Phase 2 goals, but the CONTEXT.md D-14 decision defers them to Phase 5. This creates a gap between the phase's stated success criteria and what was scoped for implementation.

**What was delivered (correctly):** Speed formatting infrastructure, real-time menu bar display with monospaced digits, 5-item context menu, em dash initial state, SMAppService login item registration, hybrid AppKit+SwiftUI entry point — all verified and wired.

**What is missing to fully satisfy the phase goal:** A user-accessible preferences mechanism for unit mode and display format, even a minimal one (menu submenus, a simple settings window, or persisted UserDefaults values that survive restarts).

---

_Verified: 2026-03-24_
_Verifier: Claude (gsd-verifier)_
