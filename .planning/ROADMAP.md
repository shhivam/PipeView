# Roadmap: Bandwidth Monitor

## Overview

This roadmap delivers a macOS menu bar bandwidth monitor in five phases, following the hard dependency chain: accurate measurement first, then visible display, then persistent storage, then popover content, then historical charts and settings. Each phase delivers a verifiable capability. The monitoring core must be correct before any UI displays data; persistence must accumulate data before historical charts can render it.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Core Monitoring Engine** - Accurate real-time per-interface network throughput measurement with energy-efficient polling
- [ ] **Phase 2: Menu Bar Display** - Live upload/download speeds visible in the macOS menu bar with configurable units and launch at login
- [ ] **Phase 3: Data Persistence and Aggregation** - SQLite storage with tiered aggregation and bounded retention for historical data
- [x] **Phase 4: Popover Shell and Interface Views** - Clickable popover window showing per-interface breakdown with dark/light mode support (completed 2026-03-24)
- [x] **Phase 5: Historical Charts, Statistics, and Settings** - Time-range historical charts, cumulative usage stats, and a preferences interface (completed 2026-03-24)

## Phase Details

### Phase 1: Core Monitoring Engine
**Goal**: The app can accurately measure real-time upload and download throughput for every active network interface, efficiently and without excessive resource usage
**Depends on**: Nothing (first phase)
**Requirements**: MON-01, MON-02, MON-06
**Success Criteria** (what must be TRUE):
  1. Running the app produces correct per-second upload and download byte counts for each active network interface (Wi-Fi, Ethernet, VPN tunnels)
  2. Loopback and inactive interfaces are automatically filtered out of results
  3. The monitoring process uses less than 1% CPU and minimal RAM during continuous operation
  4. Speed values update at regular intervals (1-2 seconds) without drift or timer accumulation
**Plans**: 2 plans

Plans:
- [x] 01-01-PLAN.md -- Project scaffolding, data models, SysctlReader, InterfaceFilter, SpeedComputation, and unit tests
- [x] 01-02-PLAN.md -- InterfaceDetector, SleepWakeHandler, NetworkMonitor engine, and integration tests

### Phase 2: Menu Bar Display
**Goal**: Users can see their current network speeds at a glance in the macOS menu bar, formatted to their preference, every time their Mac starts
**Depends on**: Phase 1
**Requirements**: BAR-01, BAR-02, BAR-03, BAR-04, SYS-01
**Success Criteria** (what must be TRUE):
  1. The menu bar shows current upload and download speeds as text (e.g., up-arrow 1.2 MB/s down-arrow 45 KB/s) that updates in real time
  2. User can change display units (auto-scale, KB/s, MB/s, Gb/s) and the menu bar text updates accordingly
  3. User can switch display format between upload+download, download only, upload only, or combined total
  4. Menu bar text does not jitter or cause neighboring menu bar items to shift when values change
  5. The app starts automatically when macOS boots without requiring manual launch
**Plans**: 2 plans
**UI hint**: yes

Plans:
- [x] 02-01-PLAN.md -- SpeedFormatter and SpeedTextBuilder with TDD (formatting engine for speed text display)
- [x] 02-02-PLAN.md -- StatusBarController, AppDelegate, hybrid AppKit+SwiftUI entry point, and login item registration

### Phase 3: Data Persistence and Aggregation
**Goal**: The app silently records and aggregates all bandwidth data into SQLite so historical views can query it efficiently
**Depends on**: Phase 2
**Requirements**: MON-03, MON-04, MON-05
**Success Criteria** (what must be TRUE):
  1. Bandwidth samples are continuously written to SQLite at regular intervals while the app runs
  2. Raw samples are automatically aggregated into minute, hour, day, week, and month granularity tiers
  3. Old raw samples are pruned while aggregated data is preserved, keeping the database size bounded over weeks of use
  4. Database writes do not block or degrade the monitoring loop or menu bar updates
**Plans**: 3 plans

Plans:
- [x] 03-01-PLAN.md -- GRDB/GRDBQuery SPM setup, AppDatabase with migrations, RawSample and aggregation tier record types
- [x] 03-02-PLAN.md -- BandwidthRecorder observer with snapshot accumulation, averaging, and database writing; AppDelegate wiring
- [x] 03-03-PLAN.md -- AggregationEngine cascading tier rollup, PruningManager 24h retention, background timer wiring

### Phase 4: Popover Shell and Interface Views
**Goal**: Users can click the menu bar item to see a popover window with per-interface bandwidth details, styled correctly for their system appearance
**Depends on**: Phase 3
**Requirements**: POP-01, POP-03, POP-05, POP-06
**Success Criteria** (what must be TRUE):
  1. Clicking the menu bar item opens a medium-sized popover window (approximately 400x500 pixels)
  2. The popover displays a per-interface bandwidth breakdown showing individual stats for each active interface
  3. The popover renders correctly in both dark mode and light mode, switching automatically with the system
  4. The popover includes a visible quit button that terminates the app
**Plans**: 2 plans
**UI hint**: yes

Plans:
- [x] 04-01-PLAN.md -- SwiftUI popover views: PopoverTab, SF Symbol mapping, AggregateHeaderView, InterfaceRowView, MetricsView, PopoverContentView, PreferencesPlaceholderView
- [ ] 04-02-PLAN.md -- StatusBarController refactor for left-click popover + right-click context menu, unit tests, human verification

### Phase 5: Historical Charts, Statistics, and Settings
**Goal**: Users can view historical bandwidth charts across multiple time ranges, see cumulative usage statistics, and configure all app preferences in one place
**Depends on**: Phase 4
**Requirements**: POP-02, POP-04, SYS-02
**Success Criteria** (what must be TRUE):
  1. The popover shows bar or area charts of historical bandwidth data with switchable time ranges (last hour, day, week, month)
  2. The popover displays cumulative statistics showing total data transferred today, this week, and this month
  3. A preferences interface allows the user to configure display units, display format, update interval, and other settings
  4. Chart data loads quickly from pre-aggregated tables without visible delay when switching time ranges
**Plans**: 3 plans
**UI hint**: yes

Plans:
- [x] 05-01-PLAN.md -- Data layer foundation: shared types (PreferenceKeys, ByteFormatter, HistoryTimeRange, ChartDataPoint), AppDatabase query methods, unit tests
- [x] 05-02-PLAN.md -- History tab UI: PopoverTab.history, HistoryView, HistoryChartView, CumulativeStatsView, StatCardView, PopoverContentView updates
- [x] 05-03-PLAN.md -- Preferences UI and wiring: PreferencesView, StatusBarController preference reading, NetworkMonitor interval update, human verification

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4 -> 5

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Core Monitoring Engine | 0/2 | Planned | - |
| 2. Menu Bar Display | 0/2 | Planned | - |
| 3. Data Persistence and Aggregation | 0/3 | Planned | - |
| 4. Popover Shell and Interface Views | 0/2 | Complete    | 2026-03-24 |
| 5. Historical Charts, Statistics, and Settings | 3/3 | Complete   | 2026-03-24 |
