# Bandwidth Monitor

## What This Is

A macOS menu bar application that monitors real-time network throughput (upload/download) per network interface, displays live speeds in the menu bar with user-configurable units, and provides beautiful graphs of historical bandwidth usage in a popover window. Data is persisted locally in SQLite for viewing usage across minutes, hours, days, weeks, and months.

## Core Value

Reliable, always-visible network throughput monitoring — the user can glance at the menu bar and instantly know their current upload/download speeds, and open the popover to understand usage patterns over time.

## Current State

Shipped v1.0 MVP with 4,543 lines of Swift across 7 phases and 14 plans.

Tech stack: Swift 6.0 + SwiftUI + AppKit hybrid, GRDB.swift 7.10.0 for SQLite, Swift Charts for historical visualizations, sysctl IFMIB_IFDATA for network byte counters, NWPathMonitor for interface detection, SystemConfiguration for human-readable interface names.

Architecture: ~20% AppKit (NSStatusItem, NSPopover, AppDelegate) + ~80% SwiftUI (popover content, charts, preferences). @Observable pattern throughout with strict concurrency.

## Requirements

### Validated

- ✓ Real-time upload/download throughput measurement per network interface — v1.0
- ✓ Per-interface breakdown (Wi-Fi, Ethernet, etc.) — v1.0
- ✓ Menu bar display showing current speeds as text (e.g. ↑ 1.2 MB/s ↓ 45 KB/s) — v1.0
- ✓ Fixed-width formatting to prevent menu bar jitter — v1.0
- ✓ User-configurable display units (KB/s, MB/s, GB/s, auto-scale) — v1.0
- ✓ User-configurable display format (upload+download, download only, upload only, combined) — v1.0
- ✓ SQLite local database for persistent data storage — v1.0
- ✓ Data recording at minute, hour, day, week, month granularity — v1.0
- ✓ Old raw samples pruned while aggregates preserved — v1.0
- ✓ Popover window (400x550px) on menu bar click with tabbed interface — v1.0
- ✓ Per-interface bandwidth breakdown with individual stats — v1.0
- ✓ Bar charts for historical data usage with switchable time ranges (1H, 24H, 7D, 30D) — v1.0
- ✓ Cumulative usage statistics (Today, This Week, This Month) — v1.0
- ✓ Preferences interface (display mode, unit, update interval, launch at login) — v1.0
- ✓ Dark mode and light mode automatic support — v1.0
- ✓ Quit button via right-click context menu — v1.0
- ✓ Launch at login via SMAppService — v1.0
- ✓ Less than 1% CPU during normal operation — v1.0

### Active

- ✓ Merge Metrics + History into a single combined tab — Phase 8
- ✓ Replace NSPopover with floating utility panel — Phase 8
- [ ] Fix chart hover behavior (y-axis shift / compression)
- [ ] Fix 7D view — one bar per day with proper labels
- [ ] Fix 30D view — one bar per day with proper labels
- [ ] Human-readable y-axis labels (KB/MB/GB)
- [ ] Fix stat card text wrapping

## Current Milestone: v1.1 UI Polish & Chart Fixes

**Goal:** Improve the popover UI — combine tabs, fix chart rendering issues, and upgrade to a floating panel window for more space.

**Target features:**
- Merge Metrics + History into single combined tab (live speeds at top, charts + stats below)
- Replace NSPopover with floating utility panel (always-on-top, dismisses on focus loss)
- Fix chart hover, 7D/30D views, y-axis formatting, and stat card layout

### Out of Scope

- Per-application bandwidth breakdown — requires nettop/Network Extension, pushes CPU from <1% to 5-15%
- Speed tests (Speedtest.net style) — different product category; measures max capability, not actual throughput
- Cloud sync / multi-device — massive scope increase; local-only tool
- Network diagnostics / traceroute — different product category
- macOS widgets — WidgetKit refreshes every 5-15 min, misleading for real-time data
- Mobile app — macOS only
- Data cap alerts / notifications — deferred to v2

## Context

- Native macOS app in Swift 6.0 with strict concurrency
- Hybrid AppKit+SwiftUI: NSStatusItem for menu bar text, floating NSPanel for window, SwiftUI for all content
- Network stats via sysctl IFMIB_IFDATA (64-bit counters, avoids NET_RT_IFLIST2 batching/truncation bugs)
- SQLite via GRDB.swift with 5-tier aggregation (raw → minute → hour → day → week/month)
- Charts via Swift Charts framework (macOS 13+)
- 100 git commits, 4,543 LOC Swift

## Constraints

- **Platform**: macOS only — native Swift, no cross-platform frameworks
- **Data storage**: SQLite — simple, local, no server
- **Architecture**: Modular and debuggable — clear separation between monitoring, storage, and UI layers
- **macOS version**: Target macOS 13+ (for Swift Charts and modern SwiftUI APIs)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Swift + SwiftUI + AppKit hybrid | Native macOS, SwiftUI for content, AppKit for menu bar performance | ✓ Good — clean separation, <1% CPU |
| GRDB.swift for SQLite | Type-safe queries, migrations, WAL mode, ValueObservation | ✓ Good — reliable, excellent test support via DatabaseQueue |
| sysctl IFMIB_IFDATA | 64-bit counters, avoids NET_RT_IFLIST2 batching/truncation bugs | ✓ Good — accurate readings, but Apple could patch no-batching behavior |
| Per-interface monitoring | User wants breakdown by Wi-Fi/Ethernet/VPN | ✓ Good — SF Symbols per interface type |
| 5-tier aggregation | Cascading rollup (raw→min→hr→day→wk/mo) with watermarks | ✓ Good — efficient queries, bounded DB size |
| @Observable pattern | Swift 6.0 strict concurrency with @MainActor | ✓ Good — compile-time data race safety |
| No alerts in v1 | Keep scope focused on monitoring and visualization | ✓ Good — shipped clean, deferred to v2 |
| withObservationTracking | Re-registration pattern for BandwidthRecorder/StatusBarController | ⚠ Revisit — verbose; consider AsyncStream in future |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition:**
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone:**
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-03-24 after Phase 8 (Panel & Tab Restructure) complete*
