---
phase: 01-core-monitoring-engine
plan: 02
subsystem: monitoring
tags: [swift, NWPathMonitor, SystemConfiguration, Observable, network-monitoring, macos, concurrency]

# Dependency graph
requires:
  - phase: 01-core-monitoring-engine plan 01
    provides: "SysctlReader, InterfaceFilter, SpeedComputation, NetworkSample types, Loggers"
provides:
  - "InterfaceDetector: NWPathMonitor + SystemConfiguration interface detection with name resolution"
  - "SleepWakeHandler: NSWorkspace wake notification observer for post-sleep sample discard"
  - "NetworkMonitor: @MainActor @Observable engine with polling loop, speed computation, published state"
  - "Full monitoring pipeline: detect interfaces -> read counters -> compute speed -> publish state"
affects: [02-menu-bar-display, 03-persistence-layer, 04-popover-ui]

# Tech tracking
tech-stack:
  added: [Network framework (NWPathMonitor), SystemConfiguration (SCNetworkInterface), Observation (@Observable), AppKit (NSWorkspace.didWakeNotification)]
  patterns: [@MainActor @Observable for SwiftUI-consumable engine state, NWPathMonitor + poll-cycle re-enumeration (D-06), ContinuousClock for elapsed time, structured concurrency polling with Task.sleep tolerance]

key-files:
  created:
    - BandwidthMonitor/Monitoring/InterfaceDetector.swift
    - BandwidthMonitor/Monitoring/SleepWakeHandler.swift
    - BandwidthMonitor/Monitoring/NetworkMonitor.swift
    - BandwidthMonitorTests/InterfaceDetectorTests.swift
    - BandwidthMonitorTests/NetworkMonitorTests.swift
  modified:
    - BandwidthMonitor.xcodeproj/project.pbxproj

key-decisions:
  - "@MainActor @Observable for NetworkMonitor -- SwiftUI models must be @MainActor for direct observation, not a custom actor"
  - "ContinuousClock.Instant for elapsed time -- does not pause during sleep, unlike SuspendingClock"
  - "Poll-cycle re-enumeration via refreshInterfaces() as safety net (D-06) in addition to NWPathMonitor event-driven updates"
  - "Task.sleep tolerance of 500ms for CPU coalescing and energy efficiency"

patterns-established:
  - "Pattern: @MainActor @Observable engine class with published state for SwiftUI consumption"
  - "Pattern: Hybrid NWPathMonitor (event-driven) + poll-cycle re-enumeration for interface detection"
  - "Pattern: SleepWakeHandler with closure callback for decoupled wake notification handling"
  - "Pattern: Graduated logging -- debug for individual failures, warning after 5+ consecutive failures (D-10)"

requirements-completed: [MON-01, MON-02, MON-06]

# Metrics
duration: 4min
completed: 2026-03-23
---

# Phase 01 Plan 02: Monitoring Engine Summary

**NWPathMonitor interface detection with SystemConfiguration name resolution, sleep/wake handling, and @Observable NetworkMonitor engine orchestrating the full polling pipeline**

## Performance

- **Duration:** 4 min
- **Started:** 2026-03-23T17:37:38Z
- **Completed:** 2026-03-23T17:41:52Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments
- Implemented InterfaceDetector combining NWPathMonitor (event-driven) with SystemConfiguration (BSD-to-display-name resolution) and per-poll-cycle re-enumeration as safety net
- Implemented SleepWakeHandler observing NSWorkspace.didWakeNotification with closure callback pattern
- Implemented NetworkMonitor as @MainActor @Observable engine orchestrating the full monitoring pipeline: interface detection, sysctl counter reads, speed computation, and state publication
- All 10 locked design decisions (D-01 through D-10) are now implemented across Plan 01 and Plan 02
- All 29 tests pass across 5 test classes (19 from Plan 01 + 10 from Plan 02)

## Task Commits

Each task was committed atomically:

1. **Task 1: Implement InterfaceDetector and SleepWakeHandler** - `ed35ca9` (feat)
2. **Task 2: Implement NetworkMonitor engine with polling loop and integration tests** - `ad4de2b` (feat)

## Files Created/Modified
- `BandwidthMonitor/Monitoring/InterfaceDetector.swift` - NWPathMonitor + SystemConfiguration interface detection with kernel index lookup
- `BandwidthMonitor/Monitoring/SleepWakeHandler.swift` - NSWorkspace.didWakeNotification observer with onWake closure
- `BandwidthMonitor/Monitoring/NetworkMonitor.swift` - @MainActor @Observable engine with polling loop, speed computation, published state
- `BandwidthMonitorTests/InterfaceDetectorTests.swift` - 4 integration tests: detection, loopback filtering, display names, kernel indices
- `BandwidthMonitorTests/NetworkMonitorTests.swift` - 6 tests: start/stop, double start, state clearing, speed data production, configurable interval, default interval
- `BandwidthMonitor.xcodeproj/project.pbxproj` - Added 5 new source files to Xcode project

## Decisions Made
- Used @MainActor @Observable for NetworkMonitor (not a custom actor) since SwiftUI views must observe @MainActor objects directly
- Used ContinuousClock.Instant for elapsed time measurement -- does not pause during sleep, avoiding skewed speed calculations
- Called interfaceDetector.refreshInterfaces() on every poll cycle as safety net (D-06), not just on NWPathMonitor events
- Set Task.sleep tolerance to 500ms for energy-efficient CPU coalescing on polling timer

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- NetworkMonitor is the complete public API for Phase 2 (Menu Bar Display) consumption
- Phase 2 can instantiate NetworkMonitor, call start(), and observe interfaceSpeeds/aggregateSpeed/latestSnapshot
- All 10 design decisions (D-01 through D-10) are fully implemented
- No blockers for Phase 2

## Self-Check: PASSED

- All 5 created files verified present on disk
- All 2 commits verified in git log (ed35ca9, ad4de2b)
- Build: BUILD SUCCEEDED
- Tests: TEST SUCCEEDED (29/29 pass across 5 test classes)

---
*Phase: 01-core-monitoring-engine*
*Completed: 2026-03-23*
