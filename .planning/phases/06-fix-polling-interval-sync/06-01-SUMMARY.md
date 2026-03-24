---
phase: 06-fix-polling-interval-sync
plan: 01
subsystem: persistence
tags: [bandwidth-recorder, polling-interval, preference-sync, tdd]

# Dependency graph
requires:
  - phase: 03-data-persistence-aggregation
    provides: BandwidthRecorder with pollingInterval parameter and RawSample writing
  - phase: 05-historical-charts-stats-settings
    provides: Preferences UI with UpdateIntervalPref and AppDelegate observer wiring
provides:
  - Mutable BandwidthRecorder.pollingInterval that can be updated at runtime
  - AppDelegate wiring that syncs both NetworkMonitor and BandwidthRecorder on preference change
  - UpdateIntervalPref.timeInterval computed property for TimeInterval conversion
  - Tests covering 1s, 2s, and 5s polling intervals plus runtime mutation
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Single initialInterval computation reused for both NetworkMonitor and BandwidthRecorder"
    - "Preference observer updates all dependent components in single callback"

key-files:
  created: []
  modified:
    - BandwidthMonitor/Persistence/BandwidthRecorder.swift
    - BandwidthMonitor/AppDelegate.swift
    - BandwidthMonitor/Shared/PreferenceKeys.swift
    - BandwidthMonitorTests/BandwidthRecorderTests.swift

key-decisions:
  - "Single-character fix (let -> var) for BandwidthRecorder.pollingInterval rather than reconstructing the recorder"
  - "Added timeInterval computed property to UpdateIntervalPref for clean TimeInterval conversion"
  - "Moved initialInterval computation before do-catch block to deduplicate and share across both components"

patterns-established:
  - "Preference observer syncs all polling-dependent components in a single callback"

requirements-completed: [MON-03, MON-04, POP-02, POP-04]

# Metrics
duration: 2min
completed: 2026-03-24
---

# Phase 06 Plan 01: Fix Polling Interval Sync Summary

**Fixed BandwidthRecorder to use mutable pollingInterval synced with user preferences, ensuring correct byte calculations at 1s/2s/5s intervals**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-24T07:58:04Z
- **Completed:** 2026-03-24T08:00:31Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- BandwidthRecorder.pollingInterval changed from immutable `let` to mutable `var`, enabling runtime updates
- AppDelegate now passes user's preferred interval to BandwidthRecorder at init and syncs it on preference change
- Three new TDD tests verify correct byte calculations at 1s, 5s, and runtime-mutated intervals
- All 9 BandwidthRecorderTests pass (6 existing + 3 new)

## Task Commits

Each task was committed atomically:

1. **Task 1: Make BandwidthRecorder.pollingInterval mutable and add multi-interval tests (TDD)**
   - `ebff3a1` (test: add failing tests for multi-interval polling)
   - `3339c6d` (feat: make BandwidthRecorder.pollingInterval mutable)
2. **Task 2: Wire AppDelegate preference observer to sync BandwidthRecorder.pollingInterval** - `f90cce9` (feat)

## Files Created/Modified

- `BandwidthMonitor/Persistence/BandwidthRecorder.swift` - Changed `let pollingInterval` to `var pollingInterval` for runtime mutability
- `BandwidthMonitor/AppDelegate.swift` - Passes initial interval to BandwidthRecorder init; syncs on preference change
- `BandwidthMonitor/Shared/PreferenceKeys.swift` - Added `timeInterval` computed property to UpdateIntervalPref
- `BandwidthMonitorTests/BandwidthRecorderTests.swift` - Added 3 new tests for 1s, 5s, and runtime interval mutation

## Decisions Made

- **Single-character fix (let -> var):** The simplest correct fix. BandwidthRecorder already reads pollingInterval at point of use and passes it as a parameter to static functions, so making it mutable is sufficient for runtime updates.
- **timeInterval computed property:** Added to UpdateIntervalPref since BandwidthRecorder uses TimeInterval (Double) while NetworkMonitor uses Duration. Clean conversion without forcing callers to cast.
- **Deduplicated initialInterval:** Moved the computation before the do-catch block so a single declaration serves both NetworkMonitor and BandwidthRecorder initialization.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 06 is complete (single-plan phase)
- Data accuracy is now correct across all user-configurable polling intervals
- Charts and statistics downstream will reflect accurate byte values

## Self-Check: PASSED

All files verified present. All commits verified in git log (ebff3a1, 3339c6d, f90cce9).

---
*Phase: 06-fix-polling-interval-sync*
*Completed: 2026-03-24*
