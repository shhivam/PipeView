---
phase: 09
slug: chart-fixes-layout-polish
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-24
---

# Phase 09 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (Xcode built-in) |
| **Config file** | BandwidthMonitor.xcodeproj |
| **Quick run command** | `xcodebuild test -project BandwidthMonitor.xcodeproj -scheme BandwidthMonitor -only-testing:BandwidthMonitorTests -destination 'platform=macOS' 2>&1 \| tail -20` |
| **Full suite command** | `xcodebuild test -project BandwidthMonitor.xcodeproj -scheme BandwidthMonitor -destination 'platform=macOS'` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick test command
- **After every plan wave:** Run full suite command
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 09-01-01 | 01 | 1 | CHRT-01 | unit | `xcodebuild test -only-testing:BandwidthMonitorTests/ChartTests` | ❌ W0 | ⬜ pending |
| 09-01-02 | 01 | 1 | CHRT-02, CHRT-03 | unit | `xcodebuild test -only-testing:BandwidthMonitorTests/ChartTests` | ❌ W0 | ⬜ pending |
| 09-01-03 | 01 | 1 | CHRT-04 | unit | `xcodebuild test -only-testing:BandwidthMonitorTests/ChartAxisFormatterTests` | ❌ W0 | ⬜ pending |
| 09-01-04 | 01 | 1 | LYOT-01 | manual | Visual inspection | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `BandwidthMonitorTests/ChartAxisFormatterTests.swift` — unit tests for axis formatter
- [ ] Existing test infrastructure covers build verification

*Existing XCTest infrastructure is already configured.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Chart hover doesn't shift y-axis | CHRT-01 | Visual interaction behavior | Hover over bars in all time ranges, verify no layout shift |
| 7D shows 7 bars with date labels | CHRT-02 | Visual rendering | Switch to 7D view, count bars, verify labels |
| 30D shows daily bars with labels | CHRT-03 | Visual rendering | Switch to 30D view, verify bar count and label spacing |
| Y-axis shows human-readable units | CHRT-04 | Visual formatting | Check all time ranges for KB/MB/GB labels |
| Stat card text not truncated | LYOT-01 | Visual layout | Check stat cards at various data values |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
