---
phase: 3
slug: data-persistence-and-aggregation
status: draft
nyquist_compliant: true
wave_0_complete: true
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
| 03-01-02 | 01 | 1 | MON-03 | unit | `xcodebuild test -only-testing:BandwidthMonitorTests/AppDatabaseTests -quiet` | TDD inline | ⬜ pending |
| 03-02-01 | 02 | 2 | MON-03 | unit | `xcodebuild test -only-testing:BandwidthMonitorTests/BandwidthRecorderTests -quiet` | TDD inline | ⬜ pending |
| 03-03-01 | 03 | 3 | MON-04 | unit | `xcodebuild test -only-testing:BandwidthMonitorTests/AggregationEngineTests -quiet` | TDD inline | ⬜ pending |
| 03-03-01 | 03 | 3 | MON-05 | unit | `xcodebuild test -only-testing:BandwidthMonitorTests/PruningManagerTests -quiet` | TDD inline | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

**Notes:**
- All test files are created inline by their respective TDD tasks (tdd="true"), satisfying Wave 0 requirements without a separate Wave 0 plan.
- AppDatabaseTests is created by Plan 01 Task 2 (tdd="true").
- BandwidthRecorderTests is created by Plan 02 Task 1 (tdd="true").
- AggregationEngineTests and PruningManagerTests are created by Plan 03 Task 1 (tdd="true").

---

## Wave 0 Requirements

All Wave 0 requirements are satisfied by TDD inline tasks:

- [x] `BandwidthMonitorTests/AppDatabaseTests.swift` — created by Plan 01 Task 2 (tdd="true"), covers MON-03
- [x] `BandwidthMonitorTests/BandwidthRecorderTests.swift` — created by Plan 02 Task 1 (tdd="true"), covers MON-03
- [x] `BandwidthMonitorTests/AggregationEngineTests.swift` — created by Plan 03 Task 1 (tdd="true"), covers MON-04
- [x] `BandwidthMonitorTests/PruningManagerTests.swift` — created by Plan 03 Task 1 (tdd="true"), covers MON-05
- [x] GRDB.swift SPM dependency added to test target (BandwidthMonitorTests must link GRDB) — Plan 01 Task 1
- [x] Use in-memory `DatabaseQueue(path: ":memory:")` for tests (faster, no cleanup)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| DB writes don't block menu bar updates | MON-03 | Requires observing UI responsiveness during writes | Run app, transfer large file, verify menu bar speeds update smoothly without stutter |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references (all satisfied by TDD inline)
- [x] No watch-mode flags
- [x] Feedback latency < 15s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
