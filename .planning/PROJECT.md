# Bandwidth Monitor

## What This Is

A macOS menu bar application that monitors real-time network throughput (upload/download) per network interface, displays live speeds in the menu bar with user-configurable units, and provides beautiful graphs of historical bandwidth usage in a popover window. Data is persisted locally in SQLite for viewing usage across minutes, hours, days, weeks, and months.

## Core Value

Reliable, always-visible network throughput monitoring — the user can glance at the menu bar and instantly know their current upload/download speeds, and open the popover to understand usage patterns over time.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Real-time upload/download throughput measurement per network interface
- [ ] Menu bar display showing current speeds as text (e.g. ↑ 1.2 MB/s ↓ 45 MB/s)
- [ ] User-configurable display units (KB/s, MB/s, Gb/s, auto-scale, etc.)
- [ ] Per-interface breakdown (Wi-Fi, Ethernet, etc.)
- [ ] SQLite local database for persistent data storage
- [ ] Data recording at minute, hour, day, week, month granularity
- [ ] Medium-sized popover window (~400x500px) on menu bar click
- [ ] Time series line/area charts for recent bandwidth activity
- [ ] Bar charts for historical data usage summaries (today, this week, this month)
- [ ] Switchable time range views (last hour, day, week, month)
- [ ] Clean, modular Swift codebase with clear separation of concerns

### Out of Scope

- Speed tests (Speedtest.net style) — not the goal, this is about live throughput monitoring
- Data cap alerts / notifications — not needed for v1
- Mobile app — macOS only
- Per-application bandwidth breakdown — OS-level interface monitoring only
- Real-time chat or cloud sync — purely local tool

## Context

- Built as a native macOS app in Swift
- Menu bar apps use NSStatusItem + NSPopover pattern
- Network stats available via macOS system APIs (likely `nw_path_monitor` or reading from IOKit/sysctl)
- SQLite via Swift packages (e.g., GRDB or SQLite.swift)
- Charts via Swift Charts framework (macOS 13+) or a charting library
- Should be easy to debug — clean architecture, modular components

## Constraints

- **Platform**: macOS only — native Swift, no cross-platform frameworks
- **Data storage**: SQLite — simple, local, no server
- **Architecture**: Modular and debuggable — clear separation between monitoring, storage, and UI layers
- **macOS version**: Target macOS 13+ (for Swift Charts and modern SwiftUI APIs)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Swift + SwiftUI | Native macOS, modern UI framework, good menu bar app support | — Pending |
| SQLite for storage | Simple, local, no dependencies on external services | — Pending |
| Per-interface monitoring | User wants to see breakdown by Wi-Fi/Ethernet/etc. | — Pending |
| No alerts in v1 | Keep scope focused on monitoring and visualization | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd:transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-03-23 after initialization*
