---
phase: 4
slug: popover-shell-and-interface-views
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-24
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (built into Xcode) |
| **Config file** | BandwidthMonitorTests target in BandwidthMonitor.xcodeproj |
| **Quick run command** | `xcodebuild test -project BandwidthMonitor.xcodeproj -scheme BandwidthMonitor -destination 'platform=macOS' -only-testing:BandwidthMonitorTests -quiet` |
| **Full suite command** | `xcodebuild test -project BandwidthMonitor.xcodeproj -scheme BandwidthMonitor -destination 'platform=macOS' -quiet` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild test -project BandwidthMonitor.xcodeproj -scheme BandwidthMonitor -destination 'platform=macOS' -only-testing:BandwidthMonitorTests -quiet`
- **After every plan wave:** Run `xcodebuild test -project BandwidthMonitor.xcodeproj -scheme BandwidthMonitor -destination 'platform=macOS' -quiet`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 04-01-01 | 01 | 1 | POP-01 | unit | Verify NSPopover contentSize is set to 400x500 | ❌ W0 | ⬜ pending |
| 04-01-02 | 01 | 1 | POP-03 | unit | Verify InterfaceRowView renders with test data, MetricsView shows correct row count | ❌ W0 | ⬜ pending |
| 04-01-03 | 01 | 1 | POP-06 | unit | Verify context menu contains "Quit Bandwidth Monitor" item with correct action | ❌ W0 | ⬜ pending |
| 04-01-04 | 01 | 1 | POP-05 | manual-only | Visual dark/light mode inspection | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `BandwidthMonitorTests/PopoverTests.swift` — stubs for POP-01 (contentSize), POP-06 (context menu items), SF Symbol mapping, PopoverTab state
- [ ] No new test fixtures needed — existing test infrastructure (XCTest, in-memory database) is sufficient
- [ ] No framework install needed — XCTest is built into Xcode

*Existing infrastructure covers framework requirements.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Dark/light mode rendering | POP-05 | Semantic SwiftUI colors auto-adapt; no custom colors to test programmatically. Visual inspection required. | 1. Open System Settings > Appearance. 2. Switch between Light and Dark. 3. Open popover — verify all text, icons, and backgrounds adapt correctly. 4. No custom hex values should be visible. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
