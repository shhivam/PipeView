---
phase: 1
slug: core-monitoring-engine
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-23
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (built into Xcode) |
| **Config file** | None — Wave 0 must create test target |
| **Quick run command** | `xcodebuild test -scheme BandwidthMonitor -only-testing BandwidthMonitorTests -destination 'platform=macOS'` |
| **Full suite command** | `xcodebuild test -scheme BandwidthMonitor -destination 'platform=macOS'` |
| **Estimated runtime** | ~10 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick tests on modified test files
- **After every plan wave:** Run full suite
- **Before `/gsd:verify-work`:** Full suite must be green + manual Instruments verification for MON-06
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 01-01-01 | 01 | 1 | MON-01 | unit | `xcodebuild test -only-testing BandwidthMonitorTests/SysctlReaderTests -destination 'platform=macOS'` | ❌ W0 | ⬜ pending |
| 01-01-02 | 01 | 1 | MON-01 | unit | `xcodebuild test -only-testing BandwidthMonitorTests/SpeedComputationTests -destination 'platform=macOS'` | ❌ W0 | ⬜ pending |
| 01-01-03 | 01 | 1 | MON-01 | unit | `xcodebuild test -only-testing BandwidthMonitorTests/SpeedComputationTests/testCounterReset -destination 'platform=macOS'` | ❌ W0 | ⬜ pending |
| 01-02-01 | 02 | 1 | MON-02 | unit | `xcodebuild test -only-testing BandwidthMonitorTests/InterfaceFilterTests -destination 'platform=macOS'` | ❌ W0 | ⬜ pending |
| 01-02-02 | 02 | 1 | MON-02 | integration | `xcodebuild test -only-testing BandwidthMonitorTests/InterfaceDetectorTests -destination 'platform=macOS'` | ❌ W0 | ⬜ pending |
| 01-03-01 | 03 | 2 | MON-06 | manual | Instruments Time Profiler — run app for 60s, verify < 1% CPU | N/A | ⬜ pending |
| 01-03-02 | 03 | 2 | MON-06 | manual | Instruments Allocations — run app for 5 min, check growth | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Xcode project creation (File > New > Project > macOS > App)
- [ ] Test target creation (BandwidthMonitorTests)
- [ ] SPM dependency: swift-collections 1.1.0+
- [ ] `Tests/SysctlReaderTests.swift` — stubs for MON-01 (sysctl reads)
- [ ] `Tests/SpeedComputationTests.swift` — stubs for MON-01 (speed math)
- [ ] `Tests/InterfaceFilterTests.swift` — stubs for MON-02 (interface filtering)
- [ ] `Tests/InterfaceDetectorTests.swift` — stubs for MON-02 (name resolution)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| CPU usage < 1% during polling | MON-06 | Requires Instruments profiler | Run app for 60s with Instruments Time Profiler, verify CPU samples < 1% |
| No memory leaks during sustained polling | MON-06 | Requires Instruments Allocations | Run app for 5 min, verify no persistent memory growth |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
