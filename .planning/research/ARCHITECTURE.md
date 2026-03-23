# Architecture Research

**Domain:** macOS menu bar network bandwidth monitor
**Researched:** 2026-03-23
**Confidence:** HIGH

## Standard Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                      Presentation Layer                         │
│  ┌──────────────┐  ┌──────────────────┐  ┌──────────────────┐  │
│  │ MenuBarView  │  │  PopoverView     │  │  SettingsView    │  │
│  │ (NSStatusItem│  │  (Charts, Tabs,  │  │  (Preferences)   │  │
│  │  text label) │  │   Interface List)│  │                  │  │
│  └──────┬───────┘  └────────┬─────────┘  └────────┬─────────┘  │
│         │                   │                      │            │
├─────────┴───────────────────┴──────────────────────┴────────────┤
│                      State Layer (@Observable)                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │               AppState / ViewModels                      │   │
│  │  - currentSpeeds: [InterfaceID: (up, down)]              │   │
│  │  - selectedInterface: InterfaceID?                       │   │
│  │  - displayUnit: SpeedUnit                                │   │
│  │  - timeRange: TimeRange                                  │   │
│  └──────────────────────┬───────────────────────────────────┘   │
│                         │                                       │
├─────────────────────────┴───────────────────────────────────────┤
│                      Service Layer                              │
│  ┌──────────────────┐  ┌──────────────────┐                     │
│  │ NetworkMonitor   │  │ DataAggregator   │                     │
│  │ (sysctl polling, │  │ (rollup minute   │                     │
│  │  delta calc,     │  │  -> hour -> day  │                     │
│  │  per-interface)  │  │  -> week -> month│                     │
│  └────────┬─────────┘  └────────┬─────────┘                     │
│           │                     │                               │
├───────────┴─────────────────────┴───────────────────────────────┤
│                      Persistence Layer                          │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              GRDB / SQLite (DatabasePool)                │   │
│  │  - raw_samples (timestamp, interface, bytes_in, bytes_out│   │
│  │  - hourly_rollups, daily_rollups, monthly_rollups        │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│                      System Layer                               │
│  ┌──────────────────┐  ┌──────────────────┐                     │
│  │ sysctl()         │  │ NWPathMonitor    │                     │
│  │ NET_RT_IFLIST2   │  │ (interface       │                     │
│  │ (byte counters)  │  │  availability)   │                     │
│  └──────────────────┘  └──────────────────┘                     │
└─────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| **MenuBarView** | Renders live upload/download speeds as text in the system menu bar | NSStatusItem with attributedTitle updated on timer; SwiftUI MenuBarExtra with `.window` style for the popover |
| **PopoverView** | Shows historical charts (line/area for recent, bar for summaries), interface selector, time range picker | SwiftUI view inside MenuBarExtra window; Swift Charts for visualization |
| **SettingsView** | User preferences: display unit, polling interval, visible interfaces | SwiftUI form, persisted via UserDefaults or @AppStorage |
| **AppState** | Central observable state: current speeds, selected interface, display settings | @Observable class holding live data and user preferences |
| **NetworkMonitor** | Polls sysctl for raw byte counters, computes deltas between samples to derive throughput | DispatchSourceTimer on background queue; calls sysctl(NET_RT_IFLIST2) every 1-2 seconds |
| **DataAggregator** | Rolls up raw samples into coarser granularities; prunes old raw data | Triggered periodically (e.g., every minute for minute rollups); SQL-based aggregation |
| **GRDB/SQLite** | Persistent storage for raw samples and pre-aggregated rollups | GRDB DatabasePool in WAL mode; ValueObservation for reactive chart updates |
| **sysctl()** | macOS kernel API returning cumulative byte counters per network interface | C-level call via NET_RT_IFLIST2; parses if_msghdr2 and if_data64 structures |
| **NWPathMonitor** | Detects interface availability changes (Wi-Fi connected/disconnected, Ethernet plugged in) | Apple Network framework; used to know which interfaces exist, not for byte counts |

## Recommended Project Structure

```
BandwidthMonitor/
├── App/
│   ├── BandwidthMonitorApp.swift       # @main, MenuBarExtra scene
│   └── AppState.swift                  # @Observable central state
├── Views/
│   ├── MenuBarLabel.swift              # Formats speed text for status item
│   ├── PopoverContentView.swift        # Root popover view with tab navigation
│   ├── RecentActivityChart.swift       # Line/area chart for last hour
│   ├── HistoricalSummaryChart.swift    # Bar chart for day/week/month
│   ├── InterfacePickerView.swift       # Interface selector
│   └── SettingsView.swift              # Preferences panel
├── Services/
│   ├── NetworkMonitor.swift            # sysctl polling + delta calculation
│   ├── SystemNetworkAPI.swift          # C-interop wrapper for sysctl calls
│   ├── InterfaceTracker.swift          # NWPathMonitor wrapper for interface discovery
│   └── DataAggregator.swift            # Rollup logic (minute->hour->day->month)
├── Models/
│   ├── NetworkSample.swift             # GRDB Record: raw sample data
│   ├── AggregatedSample.swift          # GRDB Record: rollup data
│   ├── NetworkInterface.swift          # Interface metadata (name, type, id)
│   └── SpeedUnit.swift                 # Enum: KB/s, MB/s, Gb/s, auto
├── Persistence/
│   ├── DatabaseManager.swift           # GRDB DatabasePool setup + migrations
│   ├── Migrations.swift                # Schema versioning
│   └── Queries.swift                   # Reusable fetch requests for charts
├── Utilities/
│   ├── SpeedFormatter.swift            # Converts bytes/sec to display string
│   └── TimeRangeHelper.swift           # Date math for chart ranges
├── Resources/
│   └── Info.plist                      # LSUIElement = YES
└── BandwidthMonitor.entitlements       # App sandbox entitlements
```

### Structure Rationale

- **App/:** Minimal -- just the entry point and shared state. Keeps the app lifecycle clean.
- **Views/:** One file per visual component. Charts are separate from container views because they have distinct data requirements and will be iterated on independently.
- **Services/:** Business logic with no UI dependencies. NetworkMonitor owns the polling loop; SystemNetworkAPI isolates the C-interop complexity; DataAggregator handles the time-bucketing math.
- **Models/:** GRDB Record types and domain enums. These are the data contracts between layers.
- **Persistence/:** Database setup isolated from business logic. Migrations are versioned separately so schema changes are traceable.
- **Utilities/:** Pure functions with no state. Formatting and date math are used across multiple views and services.

## Architectural Patterns

### Pattern 1: Polling with Delta Calculation

**What:** The app periodically reads cumulative byte counters from the kernel via sysctl, stores the previous reading, and computes the difference to derive instantaneous throughput (bytes per second).

**When to use:** Always -- this is the fundamental measurement mechanism. sysctl returns monotonically increasing counters, not rates.

**Trade-offs:**
- Pro: Low CPU overhead (single sysctl call per sample), no kernel extensions needed
- Pro: Works for all interfaces simultaneously in one call
- Con: Throughput accuracy depends on polling interval consistency
- Con: First sample after app launch has no delta (needs two readings)

**Example:**
```swift
@Observable
final class NetworkMonitor {
    private var previousCounters: [String: (bytesIn: UInt64, bytesOut: UInt64)] = [:]
    private var timer: DispatchSourceTimer?

    var currentSpeeds: [String: (upload: Double, download: Double)] = [:]

    func start(interval: TimeInterval = 1.0) {
        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        timer.schedule(deadline: .now(), repeating: interval)
        timer.setEventHandler { [weak self] in self?.sample() }
        timer.resume()
        self.timer = timer
    }

    private func sample() {
        let counters = SystemNetworkAPI.readInterfaceCounters() // sysctl call
        for (iface, current) in counters {
            if let previous = previousCounters[iface] {
                let deltaIn = current.bytesIn - previous.bytesIn
                let deltaOut = current.bytesOut - previous.bytesOut
                // Divide by actual elapsed time for accuracy
                currentSpeeds[iface] = (
                    upload: Double(deltaOut),   // bytes in last interval
                    download: Double(deltaIn)
                )
            }
            previousCounters[iface] = current
        }
    }
}
```

### Pattern 2: Tiered Data Aggregation (Rollup)

**What:** Raw samples (every 1-2 seconds) are aggregated into progressively coarser buckets: minute averages, hourly averages, daily totals, monthly totals. Old fine-grained data is pruned.

**When to use:** When storing time-series data that needs to be queryable across multiple time ranges without unbounded storage growth.

**Trade-offs:**
- Pro: Bounded storage (raw data pruned after ~24 hours; minute data after ~7 days)
- Pro: Fast chart queries -- pre-aggregated data means no scanning millions of raw rows
- Con: Historical data loses precision (you see hourly averages, not second-by-second)
- Con: Aggregation logic adds complexity

**Rollup schedule:**
| Source | Target | Trigger | Retention |
|--------|--------|---------|-----------|
| Raw samples (1s) | Minute averages | Every 60s | Raw: 24 hours |
| Minute averages | Hourly averages | Every hour | Minutes: 7 days |
| Hourly averages | Daily totals | Every day | Hours: 90 days |
| Daily totals | Monthly totals | Monthly | Days: 1 year, Months: forever |

### Pattern 3: Reactive UI via @Observable + GRDB ValueObservation

**What:** The UI subscribes to data changes rather than polling the database. GRDB's ValueObservation notifies SwiftUI views when underlying table data changes. The @Observable macro on view models triggers SwiftUI re-renders only for properties that actually change.

**When to use:** For all chart data and the live speed display. Avoids manual refresh logic.

**Trade-offs:**
- Pro: UI stays in sync automatically; no manual "reload" calls
- Pro: @Observable tracks property-level access -- views only re-render when their specific data changes
- Con: Must be careful not to observe too broadly (observing entire tables causes unnecessary updates)

**Example:**
```swift
@Observable
final class ChartDataProvider {
    var hourlySamples: [AggregatedSample] = []

    private var cancellable: AnyDatabaseCancellable?

    func observe(interface: String, in dbPool: DatabasePool) {
        cancellable = ValueObservation
            .tracking { db in
                try AggregatedSample
                    .filter(Column("interface") == interface)
                    .filter(Column("granularity") == "hour")
                    .order(Column("timestamp").desc)
                    .limit(24)
                    .fetchAll(db)
            }
            .start(in: dbPool, onError: { error in
                print("Observation error: \(error)")
            }, onChange: { [weak self] samples in
                self?.hourlySamples = samples
            })
    }
}
```

## Data Flow

### Live Speed Display Flow

```
sysctl(NET_RT_IFLIST2)
    │
    ▼
SystemNetworkAPI.readInterfaceCounters()
    │  Returns: [interfaceName: (bytesIn: UInt64, bytesOut: UInt64)]
    ▼
NetworkMonitor.sample()
    │  Computes delta from previous reading
    │  Updates currentSpeeds dictionary
    ▼
AppState.currentSpeeds  (@Observable property)
    │  SwiftUI detects change
    ▼
MenuBarLabel.body
    │  Reads currentSpeeds, formats with SpeedFormatter
    ▼
NSStatusItem title updates  ("↑ 1.2 MB/s  ↓ 45 KB/s")
```

### Historical Data Flow

```
NetworkMonitor.sample()
    │  Every 1s: writes raw sample
    ▼
DatabaseManager.write(rawSample)
    │  Inserts into raw_samples table
    ▼
DataAggregator (triggered periodically)
    │  SELECT AVG(bytes_in), AVG(bytes_out)
    │  FROM raw_samples
    │  WHERE timestamp >= [bucket_start]
    │  GROUP BY strftime('%Y-%m-%d %H:%M', timestamp)
    ▼
DatabaseManager.write(aggregatedSamples)
    │  Inserts into minute_rollups / hourly_rollups / etc.
    │  Prunes old raw data
    ▼
GRDB ValueObservation triggers
    │  ChartDataProvider receives updated data
    ▼
PopoverContentView re-renders charts
```

### Interface Discovery Flow

```
NWPathMonitor (continuous)
    │  Detects interface changes
    ▼
InterfaceTracker
    │  Updates available interfaces list
    │  Maps system names (en0, en1) to friendly names (Wi-Fi, Ethernet)
    ▼
AppState.availableInterfaces  (@Observable)
    │
    ▼
InterfacePickerView updates
```

### Key Data Flows

1. **Live monitoring loop:** DispatchSourceTimer (1s interval) -> sysctl -> delta calculation -> @Observable state -> menu bar text update. This is the hot path; it must complete in <10ms to avoid visible lag.
2. **Persistence pipeline:** Raw sample -> SQLite insert (async, off main thread) -> periodic aggregation -> chart observation triggers. Writes are batched and non-blocking via DatabasePool WAL mode.
3. **User interaction:** Popover opens -> ValueObservation starts for selected time range -> chart data loads from pre-aggregated tables -> user switches time range -> new observation replaces old one.

## Scaling Considerations

This is a local-only desktop app, so "scaling" means data volume and CPU/memory efficiency, not user count.

| Concern | At 1 day | At 30 days | At 1 year |
|---------|----------|------------|-----------|
| Raw samples (1s interval) | ~86K rows | Pruned to 24h (86K) | Pruned to 24h (86K) |
| Minute rollups | ~1,440 rows | ~43K rows | Pruned to 7 days (~10K) |
| Hourly rollups | 24 rows | ~720 rows | ~8,760 rows |
| Daily rollups | 1 row | 30 rows | 365 rows |
| Monthly rollups | 0 rows | 1 row | 12 rows |
| **Estimated DB size** | ~5 MB | ~8 MB | ~15 MB |

### Scaling Priorities

1. **First bottleneck: Chart rendering with too many data points.** Swift Charts starts lagging around 20K points. Prevention: always query pre-aggregated data for charts. "Last hour" shows 60 minute-level points, not 3,600 raw samples.
2. **Second bottleneck: SQLite write contention.** Every 1-second sample triggers a write. Prevention: use DatabasePool (WAL mode) so reads for charts never block writes. Batch writes if needed (accumulate 5-10 samples, write together).
3. **Third bottleneck: Memory from raw sample retention.** 86K rows/day is manageable, but must be pruned. Prevention: DataAggregator runs a DELETE for raw samples older than 24 hours after each aggregation pass.

## Anti-Patterns

### Anti-Pattern 1: Polling the Database for Live Speed Display

**What people do:** Store every sample in SQLite, then have the UI query the database every second to get the latest speed.
**Why it's wrong:** Unnecessary I/O overhead. The live speed is already computed in memory by NetworkMonitor. Reading it back from disk adds latency and SQLite lock contention for no benefit.
**Do this instead:** Live speed flows through @Observable in-memory state. Only persist samples for historical charts. The database is for history, not for the live display.

### Anti-Pattern 2: Querying Raw Samples for Long Time Ranges

**What people do:** Run `SELECT * FROM raw_samples WHERE timestamp > 30_days_ago` to render a monthly chart.
**Why it's wrong:** Scanning millions of rows for a bar chart showing 30 bars is wildly inefficient. Swift Charts will also choke on the data volume.
**Do this instead:** Pre-aggregate into rollup tables. Monthly chart reads from `daily_rollups` (30 rows). Weekly chart reads from `hourly_rollups` (168 rows). Fast and bounded.

### Anti-Pattern 3: Using Timer Instead of DispatchSourceTimer

**What people do:** Use `Timer.scheduledTimer` on the main run loop for the sampling interval.
**Why it's wrong:** Timer fires on the main thread, blocking UI updates during the sysctl call and delta computation. Also, Timer requires an active run loop, which is fragile in a menu bar app.
**Do this instead:** Use DispatchSourceTimer on a `.utility` QoS background queue. It fires reliably without a run loop and keeps the main thread free for UI updates.

### Anti-Pattern 4: Storing Absolute Byte Counts Instead of Deltas

**What people do:** Store the cumulative byte counter from sysctl directly in the database.
**Why it's wrong:** Cumulative counters reset on reboot. You cannot derive throughput from two readings that span a reboot (delta would be negative or nonsensical). Also wastes storage since historical absolute values are meaningless.
**Do this instead:** Compute the delta immediately in NetworkMonitor. Store the delta (bytes transferred in that interval) as the raw sample. If a delta is negative (reboot detected), discard that sample.

### Anti-Pattern 5: Single-Table Time Series Without Rollups

**What people do:** Store all data in one table and rely on SQL GROUP BY for all time range queries.
**Why it's wrong:** After a month, you have ~2.6M raw rows. GROUP BY across all of them for a monthly view is slow and gets worse linearly over time.
**Do this instead:** Tiered rollup tables with bounded retention per tier. Each chart time range maps to a specific pre-aggregated table.

## Integration Points

### External Services

This app has no external service dependencies. It is fully local.

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| SystemNetworkAPI <-> NetworkMonitor | Direct function call (synchronous) | SystemNetworkAPI is a thin C-interop wrapper. Returns Swift types. Called on background thread. |
| NetworkMonitor <-> AppState | @Observable property mutation | NetworkMonitor updates `currentSpeeds` on a background queue; SwiftUI observes on main thread. Use `@MainActor` on the AppState or dispatch to main. |
| NetworkMonitor <-> DatabaseManager | Async write (fire-and-forget) | Samples are written to DB but NetworkMonitor does not wait for confirmation. DatabasePool handles concurrency. |
| DataAggregator <-> DatabaseManager | Read + write in transaction | Aggregation reads raw samples and writes rollups in a single database transaction, then prunes. |
| ChartDataProvider <-> DatabaseManager | GRDB ValueObservation (reactive) | Charts subscribe to specific queries. DatabasePool ensures reads don't block writes (WAL mode). |
| InterfaceTracker <-> AppState | @Observable property mutation | NWPathMonitor callback updates available interfaces list. |

### Critical Boundary: C Interop for sysctl

The sysctl call returns a raw byte buffer containing `if_msghdr2` structures with embedded `if_data64` fields. This C-level parsing must be isolated in `SystemNetworkAPI.swift` and must:
- Handle buffer allocation and deallocation safely
- Parse the variable-length message stream correctly
- Map interface indices to interface names via `if_indextoname()`
- Return clean Swift types (`[String: (bytesIn: UInt64, bytesOut: UInt64)]`)

This is the most error-prone component in the system. Wrapping it cleanly prevents C memory issues from leaking into the rest of the Swift codebase.

### Build Order (Dependency Chain)

The components have clear dependencies that dictate build order:

```
Phase 1: SystemNetworkAPI (sysctl wrapper)
    │     No dependencies. Can be tested in isolation with command-line output.
    ▼
Phase 2: NetworkMonitor (polling + delta calculation)
    │     Depends on: SystemNetworkAPI
    │     Can be tested by printing speeds to console.
    ▼
Phase 3: Menu bar display (NSStatusItem / MenuBarExtra)
    │     Depends on: NetworkMonitor (for live data)
    │     First visible milestone: speeds showing in menu bar.
    ▼
Phase 4: Persistence (GRDB setup + raw sample storage)
    │     Depends on: NetworkMonitor (for data to store)
    │     Can be developed in parallel with Phase 3.
    ▼
Phase 5: Popover with charts (Swift Charts + time range views)
    │     Depends on: Persistence (for chart data)
    │     Depends on: Phase 3 (menu bar exists to attach popover)
    ▼
Phase 6: Data aggregation + rollups
    │     Depends on: Persistence (for raw data to aggregate)
    │     Enhances: Phase 5 (charts now show longer time ranges efficiently)
    ▼
Phase 7: Settings + polish
         Depends on: All above (settings configure behavior of all components)
```

**Key parallelization opportunity:** Phases 3 and 4 can proceed in parallel once Phase 2 is complete. The menu bar display and the database layer are independent until the popover needs chart data.

## Sources

- [macOS Network Metrics Using sysctl()](https://milen.me/writings/macos-network-metrics-sysctl-net-rt-iflist2/) - Authoritative guide on NET_RT_IFLIST2 approach, 4GiB truncation bug, 1KiB batching [HIGH confidence]
- [Michael Tsai - macOS Network Metrics Using sysctl()](https://mjtsai.com/blog/2023/03/08/macos-network-metrics-using-sysctl/) - Additional context on sysctl limitations [HIGH confidence]
- [milend/macos-network-metrics (GitHub)](https://github.com/milend/macos-network-metrics) - Reference C implementation of NET_RT_IFLIST2 parsing [HIGH confidence]
- [elegracer/NetSpeedMonitor (GitHub)](https://github.com/elegracer/NetSpeedMonitor) - Production macOS menu bar speed monitor using sysctl with C interface [HIGH confidence]
- [GRDB.swift (GitHub)](https://github.com/groue/GRDB.swift) - SQLite toolkit with DatabasePool (WAL mode) and ValueObservation [HIGH confidence]
- [Apple: MenuBarExtra Documentation](https://developer.apple.com/documentation/swiftui/menubarextra) - Official SwiftUI MenuBarExtra API [HIGH confidence]
- [Apple: NWPathMonitor Documentation](https://developer.apple.com/documentation/network/nwpathmonitor) - Official Network framework for interface monitoring [HIGH confidence]
- [Apple: Swift Charts Documentation](https://developer.apple.com/documentation/Charts) - Official charting framework [HIGH confidence]
- [Apple: Energy Efficiency Guide - Minimize Timer Usage](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/power_efficiency_guidelines_osx/Timers.html) - Timer best practices for macOS [HIGH confidence]
- [Build a macOS menu bar utility in SwiftUI](https://nilcoalescing.com/blog/BuildAMacOSMenuBarUtilityInSwiftUI/) - MenuBarExtra architecture walkthrough [MEDIUM confidence]
- [Apple Developer Forums - Getting network statistics on macOS](https://developer.apple.com/forums/thread/751648) - Community discussion on IFMIB_IFDATA alternative [MEDIUM confidence]
- [Handling Time Series Data in SQLite Best Practices](https://moldstud.com/articles/p-handling-time-series-data-in-sqlite-best-practices) - Rollup and indexing strategies [MEDIUM confidence]

---
*Architecture research for: macOS menu bar network bandwidth monitor*
*Researched: 2026-03-23*
