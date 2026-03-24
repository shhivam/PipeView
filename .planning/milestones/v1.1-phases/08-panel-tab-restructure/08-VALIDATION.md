---
phase: 8
slug: panel-tab-restructure
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-24
---

# Phase 8 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (built into Xcode) |
| **Config file** | BandwidthMonitor.xcodeproj (test target: BandwidthMonitorTests) |
| **Quick run command** | `xcodebuild test -project BandwidthMonitor.xcodeproj -scheme BandwidthMonitor -only-testing:BandwidthMonitorTests/PopoverTests -destination 'platform=macOS'` |
| **Full suite command** | `xcodebuild test -project BandwidthMonitor.xcodeproj -scheme BandwidthMonitor -destination 'platform=macOS'` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild test -project BandwidthMonitor.xcodeproj -scheme BandwidthMonitor -only-testing:BandwidthMonitorTests/PopoverTests -destination 'platform=macOS'`
- **After every plan wave:** Run `xcodebuild test -project BandwidthMonitor.xcodeproj -scheme BandwidthMonitor -destination 'platform=macOS'`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 08-01-01 | 01 | 1 | UIST-02 | unit + manual | `xcodebuild test ...PopoverTests` | ✅ (needs update) | ⬜ pending |
| 08-01-02 | 01 | 1 | UIST-02 | manual | N/A (GUI interaction) | N/A | ⬜ pending |
| 08-02-01 | 02 | 1 | UIST-01 | unit | `xcodebuild test ...PopoverTests` | ✅ (needs update) | ⬜ pending |
| 08-02-02 | 02 | 1 | UIST-01 | manual | N/A (visual verification) | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `BandwidthMonitorTests/PopoverTests.swift` — update PopoverTab assertions for new `.dashboard`/`.preferences` enum values, update allCases count from 3 to 2, remove `.metrics` and `.history` assertions

*Existing infrastructure covers all automatable phase requirements. UIST-02 floating panel behavior is manual-only (requires macOS GUI interaction).*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Floating panel appears on menu bar click | UIST-02 | Requires GUI interaction (NSPanel window display) | Click menu bar icon → verify panel appears floating above other windows |
| Panel dismisses on click outside | UIST-02 | Requires GUI interaction (window focus change) | With panel open → click on Desktop or another app → verify panel dismisses |
| Panel dismisses on app switch | UIST-02 | Requires GUI interaction (app activation) | With panel open → Cmd+Tab to another app → verify panel dismisses |
| Combined Dashboard view shows live speeds + history | UIST-01 | Requires visual verification of layout composition | Open panel → verify aggregate speeds at top, per-interface list, divider, then chart + stats below |
| Single scrollable view | UIST-01 | Requires interaction testing of scroll behavior | Open panel → scroll down → verify entire content scrolls as one unit (no nested scroll regions) |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
