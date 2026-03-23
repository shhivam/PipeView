---
phase: 2
slug: menu-bar-display
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-23
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (built-in) |
| **Config file** | BandwidthMonitorTests target in Xcode project |
| **Quick run command** | `xcodebuild test -scheme BandwidthMonitor -only-testing BandwidthMonitorTests -quiet` |
| **Full suite command** | `xcodebuild test -scheme BandwidthMonitor -quiet` |
| **Estimated runtime** | ~10 seconds |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild test -scheme BandwidthMonitor -only-testing BandwidthMonitorTests -quiet`
- **After every plan wave:** Run `xcodebuild test -scheme BandwidthMonitor -quiet`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 02-01-01 | 01 | 1 | BAR-01 | unit | `xcodebuild test -scheme BandwidthMonitor -only-testing BandwidthMonitorTests -quiet` | ❌ W0 | ⬜ pending |
| 02-01-02 | 01 | 1 | BAR-02 | unit | `xcodebuild test -scheme BandwidthMonitor -only-testing BandwidthMonitorTests -quiet` | ❌ W0 | ⬜ pending |
| 02-01-03 | 01 | 1 | BAR-03 | unit | `xcodebuild test -scheme BandwidthMonitor -only-testing BandwidthMonitorTests -quiet` | ❌ W0 | ⬜ pending |
| 02-01-04 | 01 | 1 | BAR-04 | unit | `xcodebuild test -scheme BandwidthMonitor -only-testing BandwidthMonitorTests -quiet` | ❌ W0 | ⬜ pending |
| 02-02-01 | 02 | 1 | SYS-01 | manual | N/A — requires system restart | ❌ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `BandwidthMonitorTests/SpeedFormatterTests.swift` — unit tests for speed formatting (BAR-01, BAR-02, BAR-03, BAR-04)
- [ ] Test cases: auto-scale boundaries, adaptive precision, zero/near-zero, fixed-unit ceiling, all display format modes, monospacedDigit attribute verification

*Existing XCTest infrastructure from Phase 1 covers framework setup.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Menu bar text updates in real time | BAR-01 | Requires running app with live network traffic | Launch app, stream a video, verify speeds update every ~2 seconds |
| Menu bar text does not jitter | BAR-04 | Visual verification of pixel-level stability | Watch menu bar while speeds change between e.g., 9.9→10.0 MB/s; neighboring items must not shift |
| App starts at login | SYS-01 | Requires macOS logout/login cycle | Log out, log in, verify menu bar item appears without manual launch |
| No-network state shows em dash | BAR-01 | Requires disconnecting all network interfaces | Disable Wi-Fi and unplug Ethernet, verify "—" displayed |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
