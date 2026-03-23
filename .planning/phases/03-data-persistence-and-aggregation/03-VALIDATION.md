---
phase: 3
slug: data-persistence-and-aggregation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-24
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (built into Xcode 16.4) |
| **Config file** | BandwidthMonitor.xcodeproj (test target: BandwidthMonitorTests) |
| **Quick run command** | `xcodebuild test -project BandwidthMonitor.xcodeproj -scheme BandwidthMonitor -only-testing:BandwidthMonitorTests -quiet` |
| **Full suite command** | `xcodebuild test -project BandwidthMonitor.xcodeproj -scheme BandwidthMonitor -quiet` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild test -project BandwidthMonitor.xcodeproj -scheme BandwidthMonitor -only-testing:BandwidthMonitorTests -quiet`
- **After every plan wave:** Run `xcodebuild test -project BandwidthMonitor.xcodeproj -scheme BandwidthMonitor -quiet`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 03-01-01 | 01 | 1 | MON-03 | unit | `xcodebuild test -only-testing:BandwidthMonitorTests/AppDatabaseTests -quiet` | ❌ W0 | ⬜ pending |
| 03-01-02 | 01 | 1 | MON-03 | unit | `xcodebuild test -only-testing:BandwidthMonitorTests/BandwidthRecorderTests -quiet` | ❌ W0 | ⬜ pending |
| 03-01-03 | 01 | 1 | MON-04 | unit | `xcodebuild test -only-testing:BandwidthMonitorTests/AggregationEngineTests -quiet` | ❌ W0 | ⬜ pending |
| 03-01-04 | 01 | 1 | MON-04 | unit | `xcodebuild test -only-testing:BandwidthMonitorTests/AggregationEngineTests -quiet` | ❌ W0 | ⬜ pending |
| 03-01-05 | 01 | 1 | MON-05 | unit | `xcodebuild test -only-testing:BandwidthMonitorTests/PruningManagerTests -quiet` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `BandwidthMonitorTests/AppDatabaseTests.swift` — stubs for MON-03 (database creation, migration, table verification)
- [ ] `BandwidthMonitorTests/BandwidthRecorderTests.swift` — stubs for MON-03 (sample accumulation and writing)
- [ ] `BandwidthMonitorTests/AggregationEngineTests.swift` — stubs for MON-04 (all tier rollups, idempotency)
- [ ] `BandwidthMonitorTests/PruningManagerTests.swift` — stubs for MON-05 (raw pruning, aggregate preservation)
- [ ] GRDB.swift SPM dependency added to test target (BandwidthMonitorTests must link GRDB)
- [ ] Use in-memory `DatabaseQueue(path: ":memory:")` for tests (faster, no cleanup)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| DB writes don't block menu bar updates | MON-03 | Requires observing UI responsiveness during writes | Run app, transfer large file, verify menu bar speeds update smoothly without stutter |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
