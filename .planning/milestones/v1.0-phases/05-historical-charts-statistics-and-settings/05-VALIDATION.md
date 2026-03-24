---
phase: 5
slug: historical-charts-statistics-and-settings
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-24
---

# Phase 5 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (built into Xcode) |
| **Config file** | BandwidthMonitor.xcodeproj (test target: BandwidthMonitorTests) |
| **Quick run command** | `xcodebuild test -project BandwidthMonitor.xcodeproj -scheme BandwidthMonitor -destination 'platform=macOS' -only-testing:BandwidthMonitorTests 2>&1 \| tail -20` |
| **Full suite command** | `xcodebuild test -project BandwidthMonitor.xcodeproj -scheme BandwidthMonitor -destination 'platform=macOS' 2>&1 \| tail -30` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick run command for phase-specific test files
- **After every plan wave:** Run full suite command
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 05-01-01 | 01 | 1 | POP-02 | unit | `xcodebuild test ... -only-testing:BandwidthMonitorTests/AppDatabaseTests/testFetchChartData` | ❌ W0 | ⬜ pending |
| 05-01-02 | 01 | 1 | POP-02 | unit | `xcodebuild test ... -only-testing:BandwidthMonitorTests/HistoryViewTests/testTimeRangeTierMapping` | ❌ W0 | ⬜ pending |
| 05-01-03 | 01 | 1 | POP-04 | unit | `xcodebuild test ... -only-testing:BandwidthMonitorTests/AppDatabaseTests/testFetchCumulativeStats` | ❌ W0 | ⬜ pending |
| 05-01-04 | 01 | 1 | POP-04 | unit | `xcodebuild test ... -only-testing:BandwidthMonitorTests/ByteFormatterTests/testFormat` | ❌ W0 | ⬜ pending |
| 05-02-01 | 02 | 1 | SYS-02 | unit | `xcodebuild test ... -only-testing:BandwidthMonitorTests/PreferencesTests/testEnumRoundtrip` | ❌ W0 | ⬜ pending |
| 05-02-02 | 02 | 1 | SYS-02 | unit | `xcodebuild test ... -only-testing:BandwidthMonitorTests/PreferencesTests/testEnumConversion` | ❌ W0 | ⬜ pending |
| 05-03-01 | 03 | 2 | POP-02 | unit | `xcodebuild test ... -only-testing:BandwidthMonitorTests/PopoverTests/testPopoverTab_historyRawValue` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `BandwidthMonitorTests/ByteFormatterTests.swift` — stubs for POP-04 byte formatting
- [ ] `BandwidthMonitorTests/PreferencesTests.swift` — stubs for SYS-02 enum roundtrip and conversion
- [ ] `BandwidthMonitorTests/HistoryViewTests.swift` — stubs for POP-02 time range mapping
- [ ] Add `testFetchChartData` and `testFetchCumulativeStats` to existing `AppDatabaseTests.swift` — stubs for POP-02 and POP-04 data layer

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Bar chart renders download/upload grouped bars | POP-02 | SwiftUI rendering not testable in XCTest | Open popover > History tab > verify grouped bars visible |
| Time range segmented control switches chart data | POP-02 | UI interaction test | Click each segment (1H, 24H, 7D, 30D) > verify chart updates |
| Cumulative stats cards show Today/Week/Month | POP-04 | SwiftUI layout verification | Open popover > History tab > verify 3 cards below chart |
| Preferences changes propagate to menu bar | SYS-02 | Cross-component integration | Change display mode > verify menu bar text updates within 2s |
| Launch at login toggle works | SYS-02 | System integration | Toggle on > check System Settings > Login Items |
| Dark/light mode rendering | POP-05 | Visual verification | Toggle system appearance > verify chart colors adapt |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
