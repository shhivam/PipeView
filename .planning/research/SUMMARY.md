# Project Research Summary

**Project:** macOS Menu Bar Bandwidth Monitor
**Domain:** Native macOS menu bar utility (network throughput monitoring)
**Researched:** 2026-03-23
**Confidence:** HIGH

## Executive Summary

This is a native macOS menu bar utility that continuously monitors per-interface network throughput and displays upload/download speeds as text in the system status bar. The standard pattern for this category — validated across multiple open-source implementations (NetSpeedMonitor, Stats, NetSpeedMonitorPro) and commercial products (iStat Menus, PeakHour) — is a hybrid AppKit/SwiftUI architecture: AppKit owns the NSStatusItem and NSPopover shell for maximum control over the menu bar text, while SwiftUI renders all content inside the popover. Network byte counters come from a kernel sysctl call (IFMIB_IFDATA) at 1-2 second intervals, with delta calculation to derive throughput rates. The recommended minimum deployment target is macOS 14 (Sonoma) to gain the @Observable macro, with GRDB.swift as the SQLite persistence layer for multi-timeframe historical charts.

The competitive opportunity is clear: the market gap is a free, open-source app combining the lightweight always-on monitoring of Stats/Scaler with the persistent historical data and beautiful charts that only PeakHour offers behind a paywall. The v1 differentiator is SQLite-backed history (hour/day/week/month charts) — something no free competitor does well. The core monitoring loop, menu bar display, and popover with recent activity chart form the table-stakes foundation; the persistence layer and historical charts are what make the product worth installing over existing free options.

The top risks are all well-documented and avoidable. The sysctl API chosen (IFMIB_IFDATA) sidesteps the 1 KiB batching and 4 GiB truncation bugs that affect NET_RT_IFLIST2. Interface classification must be built from day one to avoid VPN double-counting. The SQLite schema must include a tiered aggregation strategy from the start — retrofitting this later is a high-cost migration. SwiftUI memory leaks in NSPopover are a real framework issue and must be addressed architecturally (persistent NSHostingController) during the popover phase, not deferred to polish. All of these pitfalls are Phase 1 and Phase 2 concerns; getting them right early means no expensive rewrites later.

## Key Findings

### Recommended Stack

The stack is unified around first-party Apple frameworks where possible. Swift 6.2 with its "approachable concurrency" model is required — strict concurrency checking at compile time prevents the data race bugs that would otherwise plague a multi-threaded monitoring app. The UI splits cleanly: AppKit handles the NSStatusItem and its popover anchor (for performance and control), SwiftUI handles everything inside the popover using Swift Charts for all visualization. GRDB.swift is the clear choice for persistence — it is the community standard for Swift SQLite, offers WAL-mode DatabasePool for concurrent reads/writes, and provides ValueObservation for reactive chart updates without manual polling. No third-party charting library is needed.

**Core technologies:**
- **Swift 6.2 + Xcode 26.3**: Primary language — strict concurrency catches data races at compile time; approachable concurrency simplifies async/await patterns
- **AppKit (NSStatusItem)**: Menu bar text display — direct control over status item with negligible update overhead; necessary because SwiftUI MenuBarExtra causes unnecessary re-renders on 1-second text updates
- **SwiftUI + macOS 14**: All popover content — declarative UI, native feel, @Observable for clean state management
- **Swift Charts (macOS 13+)**: Time-series and summary charts — first-party, SwiftUI-native, supports line/area/bar marks and scrollable axes
- **GRDB.swift 7.10.0 + GRDBQuery 0.11.0**: SQLite persistence — type-safe queries, WAL mode, ValueObservation, @Query property wrapper for SwiftUI integration
- **sysctl (IFMIB_IFDATA)**: Network byte counters — avoids the 1 KiB batching and 4 GiB truncation bugs in NET_RT_IFLIST2; returns 64-bit counters per interface
- **NWPathMonitor (Network framework)**: Interface discovery — detects Wi-Fi/Ethernet availability changes; does NOT provide byte counts
- **SystemConfiguration framework**: Human-readable interface names — maps en0 to "Wi-Fi", en1 to "Ethernet"
- **swift-collections (Deque)**: In-memory ring buffer for recent samples — efficient FIFO append/remove-first for the live chart data

**Critical version requirements:**
- macOS 14 minimum deployment target (for @Observable macro)
- GRDB.swift 7.10.0 (Swift 6.1+ compatible, current stable)
- Swift Charts requires macOS 13+ (import Charts, no separate package)

### Expected Features

The feature landscape divides cleanly into three tiers. The v1 foundation covers what every user expects from any bandwidth monitor; the differentiators (primarily SQLite history) are what justify building this instead of recommending an existing free tool; and several seemingly good ideas are anti-features that should be explicitly declined.

**Must have (table stakes) — v1:**
- Real-time upload/download speed in menu bar with auto-scaling units — the entire reason the app exists
- Popover on click showing recent activity chart (last 5-10 minutes) — makes the popover worth opening
- Per-interface awareness (active interface detection, loopback filtered) — core to "bandwidth monitor" identity
- Launch at login via SMAppService — a monitoring app that requires manual launch is useless
- Configurable update interval (1s/2s/5s default 1s) — expected by all serious users
- Dark/light mode support — automatic with SwiftUI, essentially free
- Quit option in popover — the single most common complaint about menu bar apps when missing

**Should have (competitive differentiators) — v1.x:**
- SQLite persistence layer — foundation for all history features; the primary technical differentiator
- Historical charts (hour/day/week/month) — what PeakHour charges $12/year for; free is a strong position
- Session and cumulative statistics ("total today: 4.2 GB") — derived from SQLite data
- Configurable menu bar display format (upload+download, download only, combined)
- Inline sparkline in menu bar — at-a-glance trend without opening popover; optional toggle

**Defer (v2+):**
- Data export (CSV/JSON) — only if users request it
- Data cap monitoring/alerts — correct implementation is complex; defer unless high demand
- Custom chart colors/themes
- Keyboard shortcut to toggle popover

**Anti-features (explicitly decline):**
- Per-app bandwidth breakdown — requires nettop or Network Extension; pushes CPU from <1% to 5-15%
- Speed test integration — different product category; muddies product identity
- Cloud sync / multi-device — scope creep for a local utility

### Architecture Approach

The architecture is a clean 4-layer system: Presentation (SwiftUI views + AppKit status item), State (@Observable view models), Service (NetworkMonitor polling loop + DataAggregator), and Persistence (GRDB DatabasePool). The live speed display follows an in-memory path — sysctl delta -> @Observable AppState -> NSStatusItem text update — keeping the hot path off disk entirely. Historical data flows through a separate persistence pipeline with tiered aggregation: raw samples (1s) aggregate to minute rollups, which aggregate to hourly, daily, and monthly tables. Chart queries always hit pre-aggregated tables, never raw samples.

**Major components:**
1. **SystemNetworkAPI**: C-interop wrapper for sysctl IFMIB_IFDATA — the most error-prone component, must be isolated; returns clean Swift types (`[String: (bytesIn: UInt64, bytesOut: UInt64)]`)
2. **NetworkMonitor**: 1-second polling loop (DispatchSourceTimer on `.utility` queue), delta calculation, writes raw samples to DB; this is the hot path (<10ms per iteration required)
3. **AppState (@Observable)**: Central state shared across all views — currentSpeeds, selectedInterface, displayUnit, timeRange; NetworkMonitor writes here, SwiftUI reads here
4. **DatabaseManager + GRDB (DatabasePool/WAL)**: SQLite persistence with migrations; WAL mode ensures chart reads never block monitoring writes
5. **DataAggregator**: Periodic background task rolling up raw samples into minute/hourly/daily/monthly tables; prunes expired raw data
6. **PopoverContentView + Swift Charts**: SwiftUI views for recent activity chart and historical summary charts; always queries pre-aggregated tables
7. **InterfaceTracker (NWPathMonitor)**: Detects interface availability changes; maps system names to friendly names via SystemConfiguration

**Key architectural patterns:**
- Polling with delta calculation (fundamental measurement mechanism)
- Tiered data aggregation with bounded retention (prevents unbounded storage growth)
- Reactive UI via @Observable + GRDB ValueObservation (no manual refresh logic)
- Persistent NSHostingController for popover (avoids SwiftUI memory leak)

### Critical Pitfalls

1. **sysctl API degradation (1 KiB batching + 4 GiB truncation)** — Use IFMIB_IFDATA instead of NET_RT_IFLIST2. Validate on release builds (not just debug) by monitoring a 5 GB file transfer. Implement overflow detection for counter wraps.

2. **VPN / virtual interface double-counting** — Build interface classification from day one: categorize physical (en0, en1), tunnel (utun*), loopback (lo0), bridge. Default "total" view monitors only active physical interface. This cannot be bolted on later without auditing stored historical data.

3. **SwiftUI memory leaks in NSPopover** — Use a persistent NSHostingController created once at app launch; show/hide the same instance rather than recreating. Run 20-open-close test in Instruments Allocations during popover development. Memory growth must be <10 MB total across 20 cycles.

4. **Timer energy drain** — Apply 10%+ tolerance to all timers. Reduce polling frequency when popover is closed (2-3s is fine for menu bar text). Detect Low Power Mode via ProcessInfo and extend interval to 3-5s. App must show "Low" energy impact in Activity Monitor after 1 hour idle.

5. **SQLite unbounded growth** — Design tiered aggregation schema before writing any data: raw (24h retention), minute rollups (7 days), hourly (90 days), daily (1 year), monthly (forever). Use WAL mode with periodic checkpointing. Flat single-table schema is a high-cost migration to fix later.

6. **Menu bar text width jitter** — Use monospace font (SF Mono) and fixed-width string formatting from day one. Variable-width text causes the entire menu bar to re-layout every second, creating visible jitter for other menu bar items. Test across the full speed range (0 B/s to 10 Gb/s).

## Implications for Roadmap

Based on the dependency chain in ARCHITECTURE.md and the pitfall-to-phase mapping in PITFALLS.md, the following phase structure is recommended. The ordering is driven by hard technical dependencies (you cannot persist data before you have data; you cannot chart history before you have persistence) and the principle that high-recovery-cost pitfalls must be addressed before the affected component is built.

### Phase 1: Core Monitoring Engine

**Rationale:** Everything else depends on accurate byte counter readings. The sysctl API choice, interface classification, and timer architecture must be correct before any UI or storage is built. Recovery cost for getting these wrong is low-to-medium individually, but combined they contaminate all downstream data.

**Delivers:** A working, accurate network monitoring core that can be tested from the command line — no UI required. SystemNetworkAPI (sysctl IFMIB_IFDATA wrapper), NetworkMonitor (delta calculation, DispatchSourceTimer with tolerance), InterfaceTracker (NWPathMonitor + interface classification including VPN handling), SpeedFormatter (auto-scaling units with hysteresis).

**Addresses:** Real-time speed measurement, per-interface awareness, configurable update interval, energy-efficient polling

**Avoids:** sysctl API degradation pitfall (choose IFMIB_IFDATA), VPN double-counting pitfall (classify interfaces now), timer energy drain pitfall (set tolerance from day one)

**Research flag:** None needed — sysctl API usage is well-documented with reference implementations available

### Phase 2: Menu Bar Display + Popover Shell

**Rationale:** The menu bar item is the product's primary UI surface and the anchor point for the popover. Must exist before any popover content can be built. The NSStatusItem text jitter and popover memory leak pitfalls must be addressed here, not deferred.

**Delivers:** Visible menu bar app — hybrid AppKit NSStatusItem showing live upload/download speeds in monospace fixed-width format, NSPopover with persistent NSHostingController, basic popover content (speed display, interface name, quit button). Launch at login (SMAppService). AppState (@Observable) wiring all components together.

**Uses:** AppKit (NSStatusItem), SwiftUI (popover content), SMAppService, @Observable (macOS 14)

**Avoids:** Menu bar text jitter pitfall (monospace + fixed-width from day one), SwiftUI memory leak pitfall (persistent NSHostingController from day one), missing quit button UX pitfall

**Research flag:** None needed — hybrid AppKit+SwiftUI pattern is well-documented

### Phase 3: Recent Activity Chart + In-Memory History

**Rationale:** The recent activity chart (last 5-10 minutes) is table stakes for the popover. It can be built on in-memory data (no SQLite needed yet) using a Deque ring buffer of recent samples, making it simpler and faster to implement than the full persistence layer. This delivers a complete v1-quality user experience before adding storage complexity.

**Delivers:** Popover with live-updating line/area chart of last 5-10 minutes of upload/download speeds. Per-interface breakdown view. Sparkline in menu bar (optional). Complete v1 feature set.

**Uses:** Swift Charts (line marks, area marks), swift-collections (Deque ring buffer), @Observable + ValueObservation for reactive chart updates

**Implements:** PopoverContentView, RecentActivityChart, InterfacePickerView

**Avoids:** Querying raw samples for chart rendering pitfall (ring buffer is pre-bounded), chart performance pitfall (60 data points max at 1-min granularity)

**Research flag:** None needed — Swift Charts API is first-party and well-documented

### Phase 4: SQLite Persistence + Data Aggregation

**Rationale:** Persistence is the primary differentiator. Must come after the monitoring core is validated (Phase 1-3) so the schema is informed by real data. The tiered aggregation schema must be designed and implemented before any historical data accumulates — retrofitting later requires complex migration.

**Delivers:** GRDB DatabasePool with WAL mode, tiered schema (raw_samples, minute_rollups, hourly_rollups, daily_rollups, monthly_rollups), DataAggregator background task, database migrations, WAL checkpointing. Data begins accumulating immediately.

**Uses:** GRDB.swift 7.10.0, GRDBQuery 0.11.0, SQL aggregation queries

**Implements:** DatabaseManager, Migrations, DataAggregator, NetworkSample/AggregatedSample models

**Avoids:** SQLite unbounded growth pitfall (tiered retention from schema design), querying raw samples for long ranges pitfall (pre-aggregated tables by design), WAL file growth pitfall (checkpointing configured at setup)

**Research flag:** Aggregation logic around timezone boundaries and DST transitions needs careful validation — this is the most complex pure-logic component in the system

### Phase 5: Historical Charts + Cumulative Statistics

**Rationale:** Once persistence is accumulating data (Phase 4), the historical chart views can be built on top. These are the features that differentiate the product from all free competitors.

**Delivers:** Multi-timeframe charts in popover (last hour / today / this week / this month), using pre-aggregated rollup tables. Cumulative statistics section ("total today: X GB", "this week: Y GB"). Configurable display format for menu bar (upload+download, download only, combined). Session statistics.

**Uses:** Swift Charts (bar marks for summaries, area marks for history), GRDB ValueObservation, GRDBQuery @Query property wrapper

**Implements:** HistoricalSummaryChart, Queries.swift (reusable fetch requests), ChartDataProvider

**Avoids:** Rendering millions of raw rows in charts (always queries pre-aggregated tables), Swift Charts performance cliff at >20K points

**Research flag:** None needed — chart time-range patterns are standard; aggregation queries are defined in Phase 4

### Phase 6: Settings, Polish, and Distribution

**Rationale:** Settings configure behavior of all other components, so they logically come last. Polish and distribution preparation (App Store or notarized direct download) have no dependencies on feature implementation order.

**Delivers:** Settings/preferences panel (update interval, display format, visible interfaces, theme), configurable menu bar display format, menu bar sparkline toggle, dark/light mode validation, App Store sandbox entitlements review, launch-at-login thorough testing (post-reboot), notarization pipeline.

**Uses:** SwiftUI Settings scene, @AppStorage, SMAppService, Swift Package Manager for release build

**Avoids:** Overly broad entitlements pitfall (audit for minimum required), launch at login not working pitfall (test actual reboot, not just toggle), MacBook notch jitter pitfall (final validation with fixed-width formatting)

**Research flag:** App Store review guidelines for macOS utilities may need checking — sysctl-based monitoring without network entitlements should be straightforward, but sandbox compatibility needs verification

### Phase Ordering Rationale

- Phases 1-2 are strictly sequential: monitoring engine must exist before the menu bar can display anything
- Phase 3 (recent activity chart) uses in-memory data only and can overlap with early Phase 4 work once the monitoring core is stable
- Phase 4 (persistence) is a prerequisite for Phase 5 (historical charts) — you need stored data before you can display history
- Phase 6 (settings/polish) is last because settings configure components that must all exist first
- The architecture research explicitly maps this same build order (Phases 1-7 in ARCHITECTURE.md), confirming the dependency chain

### Research Flags

Phases likely needing deeper research during planning:

- **Phase 4 (Data Aggregation):** Timezone boundary handling, DST transitions in time-bucketing logic, and WAL checkpoint configuration under various write patterns are genuinely complex. Plan time for research into SQLite strftime behavior across DST transitions before implementing the aggregation triggers.
- **Phase 6 (Distribution):** App Sandbox compatibility with sysctl IFMIB_IFDATA needs verification. Apple could restrict sysctl access to sandboxed apps without warning. Have a contingency plan (notarized direct distribution outside App Store) if sandbox entitlements become an issue.

Phases with standard patterns (can skip research-phase):

- **Phase 1:** sysctl IFMIB_IFDATA has reference C implementations (milend/macos-network-metrics) and is thoroughly documented
- **Phase 2:** Hybrid AppKit+SwiftUI menu bar pattern has multiple practical guides and open-source examples
- **Phase 3:** Swift Charts API is first-party with official Apple documentation; ring buffer pattern is standard
- **Phase 5:** Historical chart queries are standard time-series SQL on pre-aggregated tables

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All core technologies are first-party Apple frameworks or community-standard libraries. GRDB.swift 7.10.0 confirmed current. sysctl IFMIB_IFDATA has one medium-confidence uncertainty: Apple could patch the "no batching" behavior in a future macOS release. Mitigation is to implement IFMIB_IFDATA as primary and NET_RT_IFLIST2 as fallback. |
| Features | HIGH | Feature landscape is well-researched with direct competitor analysis (iStat Menus, PeakHour, Stats, Bandwidth+, Scaler). MVP definition is clear and validated against market. Anti-features are explicitly categorized with rationale. |
| Architecture | HIGH | Architecture is validated against multiple open-source implementations of the same problem domain. The 4-layer structure and data flows are consistent across all sources. The tiered aggregation pattern is proven for time-series SQLite workloads. |
| Pitfalls | HIGH | All 6 critical pitfalls are sourced from real bugs in production apps (exelban/stats VPN issues, documented Apple feedback numbers), Apple's official energy efficiency guide, and verified kernel bugs. Recovery costs and prevention strategies are specific and actionable. |

**Overall confidence:** HIGH

### Gaps to Address

- **sysctl IFMIB_IFDATA stability**: The absence of 1 KiB batching in the IFMIB path may be an unintended omission that Apple patches. During Phase 1, implement both IFMIB_IFDATA (primary) and NET_RT_IFLIST2 (fallback) and add a validation test that confirms byte-level accuracy on release builds. Developer ID signing also bypasses the batching restriction on NET_RT_IFLIST2, providing a second mitigation path.

- **App Sandbox + sysctl compatibility**: sysctl calls are system-level APIs. Their availability under App Sandbox has not been definitively confirmed for IFMIB_IFDATA specifically. During Phase 6, test the full release build under App Sandbox before committing to App Store distribution. If sysctl is restricted, the distribution strategy shifts to notarized direct download (no App Store).

- **DST and timezone boundary correctness**: The DataAggregator must correctly bucket samples across DST transitions (clocks spring forward/back). SQLite's strftime uses UTC; displaying "today's usage" requires timezone-aware date math. This needs explicit test cases during Phase 4 — it is the type of bug that only appears twice per year and is painful to discover in production.

- **macOS 14 minimum vs broader compatibility**: The macOS 14 minimum target is an opinionated recommendation for @Observable. If the target audience includes Macs that cannot run Sonoma (pre-2018 models), macOS 13 is a safe fallback at the cost of reverting @Observable to ObservableObject. This decision should be validated against the intended distribution channel before starting Phase 2.

## Sources

### Primary (HIGH confidence)
- [Apple Developer: Swift Charts](https://developer.apple.com/documentation/Charts) — chart types, scrollable axes, macOS 13+ availability
- [Apple Developer: MenuBarExtra](https://developer.apple.com/documentation/SwiftUI/MenuBarExtra) — SwiftUI menu bar scene API
- [Apple Developer: NWPathMonitor](https://developer.apple.com/documentation/network/nwpathmonitor) — interface availability monitoring
- [Apple Developer: SCNetworkInterface](https://developer.apple.com/documentation/systemconfiguration/scnetworkinterface) — interface name resolution
- [Apple Energy Efficiency Guide - Timers](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/power_efficiency_guidelines_osx/Timers.html) — timer tolerance and energy impact
- [GRDB.swift GitHub Releases](https://github.com/groue/GRDB.swift/releases) — version 7.10.0 confirmed current
- [GRDBQuery GitHub](https://github.com/groue/GRDBQuery) — version 0.11.0 confirmed current
- [elegracer/NetSpeedMonitor](https://github.com/elegracer/NetSpeedMonitor) — production macOS speed monitor using sysctl + SwiftUI; validates architecture
- [exelban/stats VPN issues #2723, #2143](https://github.com/exelban/stats/issues/2723) — real-world VPN double-counting bugs
- [milend/macos-network-metrics](https://github.com/milend/macos-network-metrics) — reference C implementation for NET_RT_IFLIST2 parsing
- [Jesse Squires — MacBook Notch and Menu Bar](https://www.jessesquires.com/blog/2023/12/16/macbook-notch-and-menu-bar-fixes/) — notch behavior, no API to detect visibility
- [SQLite Performance Tuning — phiresky](https://phiresky.github.io/blog/2020/sqlite-performance-tuning/) — WAL growth and VACUUM strategy
- [SwiftUI NSMenuItem memory leak — FB7539293](https://github.com/feedback-assistant/reports/issues/84) — documented framework memory leak

### Secondary (MEDIUM confidence)
- [macOS Network Metrics Using sysctl() — Milen Dyankov](https://milen.me/writings/macos-network-metrics-sysctl-net-rt-iflist2/) — IFMIB_IFDATA vs NET_RT_IFLIST2 analysis, 1 KiB batching and 4 GiB truncation bugs
- [Michael Tsai — macOS Network Metrics](https://mjtsai.com/blog/2023/03/08/macos-network-metrics-using-sysctl/) — corroboration of sysctl limitations
- [Build a macOS menu bar utility in SwiftUI](https://nilcoalescing.com/blog/BuildAMacOSMenuBarUtilityInSwiftUI/) — hybrid AppKit+SwiftUI architecture walkthrough
- [Apple Developer Forums — IFMIB_IFDATA](https://developer.apple.com/forums/thread/751648) — community discussion on IFMIB_IFDATA alternative
- [Handling Time Series Data in SQLite Best Practices](https://moldstud.com/articles/p-handling-time-series-data-in-sqlite-best-practices) — rollup and indexing strategies
- [GRDB.swift WAL file issues #739](https://github.com/groue/GRDB.swift/issues/739) — WAL/SHM file cleanup on connection close
- [Multi Blog — NSStatusItem limits](https://multi.app/blog/pushing-the-limits-nsstatusitem) — dynamic width management
- [Approachable Concurrency in Swift 6.2](https://www.avanderlee.com/concurrency/approachable-concurrency-in-swift-6-2-a-clear-guide/) — Swift 6.2 concurrency model
- [SwiftData vs GRDB comparison](https://fatbobman.com/en/posts/key-considerations-before-using-swiftdata/) — performance analysis favoring GRDB for local-only databases

---
*Research completed: 2026-03-23*
*Ready for roadmap: yes*
