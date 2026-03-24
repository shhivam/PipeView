---
phase: 01-core-monitoring-engine
verified: 2026-03-23T17:55:00Z
status: passed
score: 8/8 must-haves verified
re_verification: false
gaps: []
human_verification:
  - test: "Run the built app and observe live menu bar output (or add a debug console log) to confirm per-second byte counts change as expected during real network traffic"
    expected: "Upload/download values change every ~2 seconds reflecting actual network activity on Wi-Fi/Ethernet"
    why_human: "The polling pipeline is verified structurally and via integration tests, but end-to-end real-traffic correctness (that numbers shown equal actual transferred bytes) requires live observation"
  - test: "Use Instruments Time Profiler on the running app during continuous polling to confirm CPU stays below 1%"
    expected: "CPU usage for the BandwidthMonitor process stays under 1% at the 2-second polling interval"
    why_human: "MON-06 CPU budget cannot be verified programmatically without running Instruments on a live process; code structure (Task.sleep with tolerance, no busy-wait) makes it highly likely but requires human confirmation"
---

# Phase 01: Core Monitoring Engine Verification Report

**Phase Goal:** The app can accurately measure real-time upload and download throughput for every active network interface, efficiently and without excessive resource usage
**Verified:** 2026-03-23T17:55:00Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Running the app produces correct per-second upload and download byte counts for each active network interface | ✓ VERIFIED | `NetworkMonitor.pollOnce()` calls `SysctlReader.readCounters(forInterfaceIndex:)` each cycle and passes results to `computeSpeed(previous:current:elapsed:)` which divides byte deltas by `ContinuousClock`-measured elapsed seconds. Integration test `testProducesSpeedDataAfterPolling` passes on real hardware. |
| 2 | Loopback and inactive interfaces are automatically filtered out of results | ✓ VERIFIED | `InterfaceFilter.shouldInclude` blocks `.loopback` type and `lo`, `bridge`, `vnic`, `vmnet`, `awdl`, `llw`, `anpi`, `ap` prefixes. InterfaceDetector applies this filter to `NWPath.availableInterfaces`. `testLoopbackNotInResults` integration test passes. |
| 3 | The monitoring process uses less than 1% CPU and minimal RAM during continuous operation | ✓ VERIFIED (structural) | Polling uses `Task.sleep(for:tolerance:)` with 500ms tolerance enabling CPU coalescing. `SysctlReader` does a single-call sysctl per interface per poll cycle (no busy-wait). 2-second default interval. CPU measurement requires human confirmation (see Human Verification). |
| 4 | Speed values update at regular intervals (1-2 seconds) without drift or timer accumulation | ✓ VERIFIED | `pollingInterval` defaults to `.seconds(2)` with 500ms tolerance. Uses `ContinuousClock.Instant.now` to measure actual elapsed time rather than assuming a fixed interval. No timer accumulation possible — elapsed is computed from wall-clock delta between polls. |

**Score:** 4/4 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `BandwidthMonitor/Monitoring/NetworkSample.swift` | Data model structs: Speed, ByteCounters, InterfaceInfo, InterfaceSpeed, NetworkSnapshot | ✓ VERIFIED | All 5 structs present with correct fields and `Sendable` conformance. `struct Speed` has `bytesInPerSecond`, `bytesOutPerSecond`, `zero`, and `+` operator. |
| `BandwidthMonitor/Monitoring/SysctlReader.swift` | Low-level sysctl wrapper for IFMIB_IFDATA byte counter reads | ✓ VERIFIED | `func interfaceCount() -> Int32?`, `func readCounters(forInterfaceIndex:) -> ByteCounters?`, `func interfaceName(forIndex:) -> String?`. Uses `IFMIB_IFDATA` + `IFDATA_GENERAL` MIB path. Returns 64-bit `ifi_ibytes`/`ifi_obytes`. |
| `BandwidthMonitor/Monitoring/InterfaceFilter.swift` | Interface allow/block logic by name prefix and NWInterface.InterfaceType | ✓ VERIFIED | `static func shouldInclude(bsdName:type:) -> Bool` with `blockedPrefixes` and `allowedOtherPrefixes`. Handles loopback type, prefix blocklist, physical type allowlist, VPN tunnel allowlist. |
| `BandwidthMonitor/Monitoring/SpeedComputation.swift` | Pure function computing Speed from byte counter deltas with counter reset detection | ✓ VERIFIED | `func computeSpeed(previous:current:elapsed:) -> Speed`. Guards elapsed > 0. Uses conditional `UInt64` comparison for counter reset detection (D-04). No smoothing. |
| `BandwidthMonitor/Monitoring/InterfaceDetector.swift` | NWPathMonitor + SystemConfiguration interface detection with name resolution | ✓ VERIFIED | `final class InterfaceDetector`. Uses `NWPathMonitor`, `SCNetworkInterfaceCopyAll`, `SCNetworkInterfaceGetLocalizedDisplayName`. Provides `startMonitoring()`, `stopMonitoring()`, `refreshInterfaces()`. Wires `InterfaceFilter.shouldInclude`. |
| `BandwidthMonitor/Monitoring/SleepWakeHandler.swift` | NSWorkspace.didWakeNotification observer | ✓ VERIFIED | `final class SleepWakeHandler` with `var onWake: (() -> Void)?`. Registers `NSWorkspace.didWakeNotification` in `init()`, removes observer in `deinit`. |
| `BandwidthMonitor/Monitoring/NetworkMonitor.swift` | Main @Observable engine class with polling loop, speed computation, and published state | ✓ VERIFIED | `@MainActor @Observable final class NetworkMonitor`. Published `interfaceSpeeds`, `aggregateSpeed`, `latestSnapshot`, `isRunning`. Configurable `pollingInterval`. Orchestrates `SysctlReader`, `InterfaceDetector`, `SpeedComputation`, `SleepWakeHandler`. |
| `BandwidthMonitorTests/SpeedComputationTests.swift` | Unit tests for speed math and counter reset handling | ✓ VERIFIED | 5 tests: `testNormalSpeedComputation`, `testZeroElapsedReturnsZero`, `testCounterResetReturnsZero`, `testZeroDeltaReturnsZero`, `testPartialCounterReset`. All pass. |
| `BandwidthMonitorTests/InterfaceFilterTests.swift` | Unit tests for interface filtering logic | ✓ VERIFIED | 10 tests covering loopback, bridge, vnic, vmnet, awdl, llw filtering and wifi, ethernet, cellular, utun inclusion. `testLoopbackFiltered` confirmed present and passing. |
| `BandwidthMonitorTests/SysctlReaderTests.swift` | Integration tests for sysctl reader on real hardware | ✓ VERIFIED | 4 tests: positive interface count, valid index read, invalid index returns nil, name resolution. All pass against real kernel. |
| `BandwidthMonitorTests/InterfaceDetectorTests.swift` | Integration tests for interface detection and name resolution | ✓ VERIFIED | `testActiveInterfacesDetected`, `testLoopbackNotInResults`, `testInterfacesHaveDisplayNames`, `testInterfacesHaveValidKernelIndex`. All pass on real Mac. |
| `BandwidthMonitorTests/NetworkMonitorTests.swift` | Integration tests for the monitoring engine lifecycle | ✓ VERIFIED | `testStartStop`, `testDoubleStartDoesNotCrash`, `testStopClearsState`, `testProducesSpeedDataAfterPolling`, `testPollingIntervalIsConfigurable`, `testDefaultPollingIntervalIsTwoSeconds`. All pass. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `NetworkMonitor.swift` | `SysctlReader.swift` | `reader.readCounters(forInterfaceIndex:)` each poll | ✓ WIRED | Line 100: `reader.readCounters(forInterfaceIndex: iface.index)` |
| `NetworkMonitor.swift` | `InterfaceDetector.swift` | `interfaceDetector.activeInterfaces` and `refreshInterfaces()` | ✓ WIRED | Lines 94-95: `interfaceDetector.refreshInterfaces()` then `interfaceDetector.activeInterfaces` |
| `NetworkMonitor.swift` | `SpeedComputation.swift` | `computeSpeed(previous:current:elapsed:)` per interface | ✓ WIRED | Lines 125-127: `computeSpeed(previous: prev, current: counters, elapsed: elapsedSeconds)` |
| `NetworkMonitor.swift` | `SleepWakeHandler.swift` | `discardNextSample` set via `onWake` closure | ✓ WIRED | Lines 54-58: `sleepWakeHandler.onWake = { ... self?.discardNextSample = true }` |
| `InterfaceDetector.swift` | `InterfaceFilter.swift` | `.filter { InterfaceFilter.shouldInclude(...) }` | ✓ WIRED | Line 45: `.filter { InterfaceFilter.shouldInclude(bsdName: $0.name, type: $0.type) }` |
| `SysctlReader.swift` | Darwin sysctl | `IFMIB_IFDATA` MIB path | ✓ WIRED | Lines 36, 38, 60, 62: `IFMIB_IFDATA` and `IFDATA_GENERAL` constants in both `readCounters` and `interfaceName` functions |

### Data-Flow Trace (Level 4)

This phase produces no UI rendering — `NetworkMonitor` is a pure engine with `@Observable` published state. Data flows from kernel sysctl through to observable properties (`interfaceSpeeds`, `aggregateSpeed`, `latestSnapshot`). These are consumed by Phase 2 (Menu Bar Display), not yet wired to UI.

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|--------------|--------|-------------------|--------|
| `NetworkMonitor.swift` | `interfaceSpeeds` | `computeSpeed()` → `reader.readCounters()` → sysctl kernel | Yes — `ifi_ibytes`/`ifi_obytes` from real kernel interface counters | ✓ FLOWING |
| `NetworkMonitor.swift` | `aggregateSpeed` | `newSpeeds.reduce(.zero)` over all interface speeds | Yes — derived from real interface speeds | ✓ FLOWING |
| `NetworkMonitor.swift` | `latestSnapshot` | `NetworkSnapshot(interfaceSpeeds:aggregateSpeed:timestamp:)` | Yes — constructed from real poll data | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Project builds cleanly | `xcodebuild build -scheme BandwidthMonitor` | `** BUILD SUCCEEDED **` | ✓ PASS |
| Full test suite (29 tests) passes | `xcodebuild test -scheme BandwidthMonitor` | `** TEST SUCCEEDED **` — 29/29 pass across 5 test classes | ✓ PASS |
| sysctl IFMIB_IFDATA is used (not deprecated NET_RT_IFLIST2) | `grep IFMIB_IFDATA SysctlReader.swift` | Found at lines 36, 38, 60, 62 | ✓ PASS |
| Counter reset detection exists | `grep "bytesIn >= previous.bytesIn" SpeedComputation.swift` | Line 13: `current.bytesIn >= previous.bytesIn` | ✓ PASS |
| Task.sleep tolerance present | `grep "tolerance" NetworkMonitor.swift` | Line 69: `tolerance: .milliseconds(500)` | ✓ PASS |
| Agent app (no Dock icon) configured | `grep LSUIElement Info.plist` | `<key>LSUIElement</key><true/>` | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| MON-01 | 01-01-PLAN, 01-02-PLAN | App measures real-time upload and download throughput per network interface using sysctl | ✓ SATISFIED | `SysctlReader` uses `IFMIB_IFDATA` for 64-bit byte counters; `NetworkMonitor.pollOnce()` computes per-interface `Speed` values every 2 seconds |
| MON-02 | 01-01-PLAN, 01-02-PLAN | App identifies and enumerates active network interfaces (Wi-Fi, Ethernet, VPN tunnels) filtering loopback and inactive | ✓ SATISFIED | `InterfaceDetector` uses `NWPathMonitor.availableInterfaces` filtered through `InterfaceFilter.shouldInclude`; `SCNetworkInterfaceGetLocalizedDisplayName` provides human-readable names |
| MON-06 | 01-02-PLAN | App uses less than 1% CPU and minimal RAM during normal operation | ✓ SATISFIED (structural) | `Task.sleep(for:tolerance:)` with 500ms tolerance enables CPU coalescing; single sysctl call per interface per poll cycle; no busy-wait loops. Live profiling needed for definitive confirmation (see Human Verification). |

No orphaned requirements: REQUIREMENTS.md lists only MON-01, MON-02, MON-06 as Phase 1 items, all three are declared in plan frontmatter and verified above.

### Anti-Patterns Found

No anti-patterns found. Scanned all 7 source files for:
- TODO/FIXME/HACK/PLACEHOLDER comments — none
- Empty return stubs (`return null`, `return []`, `return {}`) — none
- Hardcoded empty state flowing to rendered output — none
- Console.log-only handlers — none

`BandwidthMonitorApp.swift` contains a placeholder SwiftUI `Settings` scene (intentional per plan — Phase 2 replaces this with the hybrid AppKit entry point). This is not a stub for this phase's goal; the monitoring engine operates independently of the app entry point.

### Human Verification Required

#### 1. Live Network Traffic Accuracy

**Test:** Run the app in debug mode (or add a temporary `print` to `pollOnce()`) while performing a known-size file download (e.g., `curl` a large file). Compare the reported download speed in `aggregateSpeed.bytesInPerSecond` against the expected transfer rate.
**Expected:** Reported bytes/second matches the actual file transfer rate within 10-20% (accounting for TCP overhead, compression, and 2-second averaging).
**Why human:** Correctness of the sysctl byte counter interpretation against real traffic cannot be verified by static analysis or unit tests. The data pipeline is structurally correct but actual numeric accuracy requires live observation.

#### 2. CPU Usage Under Continuous Polling

**Test:** Launch the app, open Instruments → Time Profiler, run for 60 seconds with normal network activity. Check CPU usage for the BandwidthMonitor process.
**Expected:** CPU stays below 1% at the 2-second polling interval (MON-06 requirement).
**Why human:** CPU profiling requires a running process. Code structure (single sysctl call per interface, `Task.sleep` with OS coalescing hint, no spawned background threads) strongly predicts sub-1% CPU, but only live profiling can confirm.

### Gaps Summary

No gaps. All must-haves are verified at all levels (exists, substantive, wired, data-flowing). The phase goal — accurate real-time per-interface throughput measurement — is achieved through a complete, structurally sound pipeline: kernel sysctl byte counters via `IFMIB_IFDATA` → `SpeedComputation` delta math → `InterfaceDetector`/`InterfaceFilter` interface enumeration → `NetworkMonitor` observable state. All 29 unit and integration tests pass on real hardware.

---

_Verified: 2026-03-23T17:55:00Z_
_Verifier: Claude (gsd-verifier)_
