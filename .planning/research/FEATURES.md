# Feature Research

**Domain:** macOS menu bar bandwidth/network throughput monitor
**Researched:** 2026-03-23
**Confidence:** HIGH

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist. Missing these = product feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Real-time upload/download speed in menu bar | Core reason anyone installs this type of app. Every competitor (iStat Menus, Stats, Bandwidth+, Scaler, NetSpeedMonitor) shows this. Without it, there is no product. | LOW | Use sysctl NET_RT_IFLIST2 for kernel-level byte counters. Display as text like "up-arrow 1.2 MB/s down-arrow 45 KB/s". |
| Auto-scaling units (KB/s, MB/s, GB/s) | Nobody wants to read "0.001 GB/s" or "1234567 B/s". Every competitor auto-scales. Displaying raw bytes is a deal-breaker. | LOW | Auto-scale by default, allow manual override (KB/s, MB/s, Gb/s, etc.) in preferences. |
| Launch at login | A monitoring app that must be manually opened every boot is useless. All competitors support this. Users expect it in every menu bar utility. | LOW | Use SMAppService (macOS 13+) or LoginItem API. Single checkbox in preferences. |
| Low resource usage (CPU < 1%, minimal RAM) | Users are hyper-sensitive to monitors that themselves consume resources. iStat Menus 7 markets itself as "most CPU-friendly." NetSpeedMonitorPro achieves ~0.5% CPU. Apps that use noticeable resources get uninstalled. | MEDIUM | Use sysctl (kernel-level) not higher-level APIs. Avoid per-process monitoring. Use Core Graphics or lightweight SwiftUI rendering. 1-second polling is fine; avoid sub-second. |
| Configurable update interval | Every serious competitor offers this (1s, 2s, 5s, 10s, 30s). Users on battery want longer intervals; users debugging want 1s. | LOW | Default to 1s. Offer preset options: 1s, 2s, 5s. Persist in UserDefaults. |
| Dark mode / light mode support | macOS apps that break in dark mode look amateur. Users expect seamless appearance adaptation. | LOW | Use system-aware SwiftUI colors and SF Symbols. Template images for menu bar icon. Automatic with SwiftUI on macOS 13+. |
| Per-interface awareness | Users want to know if traffic is on Wi-Fi vs Ethernet vs VPN. iStat Menus, Stats, and PeakHour all show interface breakdown. Without this, "which connection am I using?" goes unanswered. | MEDIUM | Enumerate interfaces via sysctl. Filter inactive and loopback (lo0) automatically. Show active interface name in popover. |
| Popover/dropdown on click | Every menu bar bandwidth app shows a popover or dropdown with more detail than the menu bar text. Just showing numbers with no expandable detail is insufficient. | MEDIUM | NSStatusItem + NSPopover pattern. Show recent throughput graph + interface info + session stats. Target ~400x500px per PROJECT.md. |
| Recent activity graph | Users expect to see "what happened in the last few minutes." A real-time scrolling line/area chart is table stakes in every competitor beyond the most minimal. iStat Menus, PeakHour, Scaler, Stats all show this. | MEDIUM | Swift Charts (macOS 13+). Line/area chart of last 5-10 minutes at 1-second granularity in the popover. Upload and download as separate series. |
| Quit option accessible from menu | Users need a way to quit the app without Force Quit. Every menu bar app puts this in the dropdown/menu. | LOW | Standard NSMenu item in the status item menu or popover footer. |

### Differentiators (Competitive Advantage)

Features that set the product apart. Not required, but valuable.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Persistent historical data (SQLite) | Most open-source monitors and even Bandwidth+ reset data on reboot. macOS Activity Monitor explicitly resets on restart. PeakHour charges $12/yr or $45 one-time for history. Offering free persistent history is a genuine differentiator. | HIGH | SQLite via GRDB or SQLite.swift. Store minute-level granularity, aggregate to hour/day/week/month. Requires data aggregation strategy and storage management (pruning old minute-level data). This is the project's biggest technical differentiator. |
| Multi-timeframe historical charts (hour/day/week/month) | PeakHour is the only competitor doing this well, and it's paid. Bar/area charts showing "today's usage", "this week", "this month" turn a speed monitor into a usage tracker. Most free tools show only real-time. | HIGH | Requires the SQLite persistence layer. Switchable time range views in popover. Use Swift Charts with different aggregation levels. This is what makes the app more than a speed readout. |
| Beautiful, native-feeling visualization | Most open-source alternatives look utilitarian. iStat Menus 7 is the gold standard for polish. A free app with iStat-quality charts and native SwiftUI design would stand out. | MEDIUM | Swift Charts gives native-quality rendering out of the box. Use accent colors, smooth animations, consistent spacing. Follow Apple HIG for menu bar extras. |
| Inline sparkline in menu bar | A tiny graph next to the speed numbers in the menu bar itself. Only iStat Menus and Stats offer this among network monitors. Provides at-a-glance trend without opening the popover. | MEDIUM | Custom drawing via Core Graphics in NSStatusItem button. Must be compact (around 30-50px wide). Optional -- some users prefer text-only for space. Make it a toggle in preferences. |
| Per-interface breakdown view | Beyond just showing the active interface -- let users see bandwidth per interface in the popover. Useful for people with both Wi-Fi and Ethernet, or VPN users who want to see VPN vs direct traffic. | MEDIUM | Already reading per-interface data from sysctl. Group and display separately in the popover UI. |
| Session and cumulative statistics | Show total data transferred this session, today, this week, this month. Bandwidth+ does monthly tracking; PeakHour does this behind a paywall. Free and well-presented cumulative stats are a draw. | MEDIUM | Derived from the SQLite historical data. Display in the popover as a summary section. |
| Configurable menu bar display format | Let users choose what the menu bar shows: upload+download, download only, upload only, combined total, or with mini-graph. iStat Menus and Bandwidth+ offer this. | LOW | Preferences panel with radio/picker for display mode. Store in UserDefaults. |

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem good but create problems.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Per-application bandwidth breakdown | Users want to know which app is using bandwidth. iStat Menus offers this. | Requires nettop or Network Extension framework, which is extremely CPU-heavy for continuous monitoring. Apple's nettop is not designed for always-on background use. Network Extension requires entitlements and privacy prompts that scare users. This single feature can push CPU usage from <1% to 5-15%. | Show a "Quick link to Activity Monitor" button in the popover. The OS already does per-app tracking well in Activity Monitor. |
| Speed test (Speedtest.net style) | Users conflate "bandwidth monitor" with "speed test." | Speed tests are a different product category entirely. They measure max throughput to a remote server, not actual usage. Including one bloats the app, requires network permissions, and confuses the product identity. PeakHour tried this and it muddied their value prop. | Clearly position as "throughput monitor, not speed test" in app description. Link to Speedtest.net/fast.com if users ask. |
| Data cap alerts / notifications | Users with ISP data caps want warnings when approaching limits. PeakHour and Bandwidth+ offer this. | Requires knowing the user's data cap (manual entry), billing cycle dates, and creates ongoing notification management complexity. Also unreliable because the app only tracks traffic from this Mac, not the whole household. Router-level monitoring is the real answer for data caps. | Defer to v2+ at earliest. Show cumulative usage stats (which naturally helps users self-monitor) without the alert infrastructure. |
| Cloud sync / multi-device monitoring | PeakHour offers iCloud sync for multi-Mac monitoring. | Massively increases scope: CloudKit integration, conflict resolution, data schema versioning, privacy considerations, iCloud entitlements. For a v1 local tool, this is pure scope creep. | Keep data local. SQLite export/import could be a v2+ feature if there's demand. |
| Network path analysis / traceroute | PeakHour does network path analysis and multi-point latency. | Different product category (network diagnostics). Adds complexity, requires elevated permissions for ICMP, and distracts from the core value of "glance at menu bar, see your speeds." | Out of scope entirely. Users who need traceroute already have terminal or dedicated tools. |
| Widget / Notification Center integration | macOS widgets could show bandwidth stats. | macOS widgets refresh infrequently (WidgetKit controls refresh timing, typically 5-15 min minimum). Real-time speed data in a widget that updates every 15 minutes is misleading. The menu bar IS the always-visible widget. | The menu bar item itself serves this purpose better than any widget can. |
| VPN-specific features | Users want to see VPN speed separately or detect VPN status. | VPN detection is unreliable across providers. utun interfaces vary. Adding VPN-specific UI adds complexity for a niche use case. | Per-interface view naturally shows VPN tunnel interfaces (utun0, etc.) without VPN-specific logic. Users can see VPN traffic by interface name. |

## Feature Dependencies

```
[Real-time speed measurement]
    |--requires--> [sysctl / network byte counter infrastructure]
    |--enables---> [Menu bar display]
    |--enables---> [Recent activity graph]
    |--enables---> [Sparkline in menu bar]

[SQLite persistence layer]
    |--requires--> [Real-time speed measurement] (data source)
    |--requires--> [Data aggregation strategy] (minute -> hour -> day)
    |--enables---> [Historical charts (hour/day/week/month)]
    |--enables---> [Session and cumulative statistics]

[Popover window]
    |--requires--> [Menu bar display] (anchor point)
    |--enables---> [Recent activity graph]
    |--enables---> [Historical charts]
    |--enables---> [Per-interface breakdown view]
    |--enables---> [Cumulative statistics display]

[Per-interface awareness]
    |--requires--> [sysctl infrastructure]
    |--enhances--> [Menu bar display] (show active interface name)
    |--enables---> [Per-interface breakdown view]

[Configurable display format]
    |--enhances--> [Menu bar display]
    |--independent of--> [SQLite persistence]

[Launch at login]
    |--independent of--> [All other features]
```

### Dependency Notes

- **Historical charts require SQLite persistence:** Cannot show "last week" without stored data. These must be built sequentially -- persistence first, then chart views on top.
- **Recent activity graph requires popover:** The graph lives inside the popover. The popover requires the menu bar item as its anchor. Build menu bar item first, then popover, then graph.
- **Sparkline is independent of popover graphs:** The menu bar sparkline and the popover charts are separate rendering paths. Sparkline can be added any time after the base menu bar display works.
- **Per-interface breakdown enhances but doesn't block core flow:** The app works with a single "all interfaces combined" view. Per-interface breakdown is an enhancement on the data already being collected.

## MVP Definition

### Launch With (v1)

Minimum viable product -- what's needed to validate the concept.

- [ ] **Real-time upload/download speed measurement** -- the foundational capability; without this, nothing else matters
- [ ] **Menu bar text display with auto-scaling units** -- the primary UI surface; users glance here 100x/day
- [ ] **Configurable update interval** -- 1s default, with 2s/5s options; trivial to implement, expected by users
- [ ] **Popover window on click** -- anchor for all detailed views; table stakes interaction pattern
- [ ] **Recent activity line/area chart** -- last 5-10 minutes of throughput; makes the popover worth opening
- [ ] **Per-interface awareness** -- show active interface, filter loopback; core to "bandwidth monitor" identity
- [ ] **Launch at login** -- non-negotiable for a menu bar utility
- [ ] **Dark/light mode support** -- automatic with SwiftUI, virtually zero extra effort
- [ ] **Quit option** -- standard menu bar app affordance

### Add After Validation (v1.x)

Features to add once core is working.

- [ ] **SQLite persistence layer** -- add once real-time monitoring is solid; foundation for all history features
- [ ] **Historical charts (hour/day/week/month)** -- add once SQLite is recording; this is the primary differentiator
- [ ] **Session and cumulative statistics** -- derived from SQLite data; "total today: 4.2 GB" etc.
- [ ] **Configurable menu bar display format** -- upload+download, download only, combined, etc.
- [ ] **Inline sparkline in menu bar** -- optional mini-graph next to speed numbers
- [ ] **Per-interface breakdown in popover** -- detailed per-interface stats table

### Future Consideration (v2+)

Features to defer until product-market fit is established.

- [ ] **Data export (CSV/JSON)** -- only if users request it; Bandwidth+ and PeakHour offer this
- [ ] **Data cap monitoring / alerts** -- complex to implement correctly; defer unless high demand
- [ ] **Customizable chart colors/themes** -- nice polish feature, low priority
- [ ] **Menu bar icon options** -- custom icons, color coding by speed level
- [ ] **Keyboard shortcut to toggle popover** -- accessibility enhancement

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Real-time speed measurement | HIGH | LOW | P1 |
| Menu bar text display | HIGH | LOW | P1 |
| Auto-scaling units | HIGH | LOW | P1 |
| Launch at login | HIGH | LOW | P1 |
| Configurable update interval | MEDIUM | LOW | P1 |
| Popover window | HIGH | MEDIUM | P1 |
| Recent activity graph | HIGH | MEDIUM | P1 |
| Per-interface awareness | MEDIUM | MEDIUM | P1 |
| Dark/light mode | HIGH | LOW | P1 |
| SQLite persistence | HIGH | HIGH | P2 |
| Historical charts | HIGH | HIGH | P2 |
| Cumulative statistics | MEDIUM | MEDIUM | P2 |
| Configurable display format | MEDIUM | LOW | P2 |
| Sparkline in menu bar | MEDIUM | MEDIUM | P2 |
| Per-interface breakdown view | LOW | MEDIUM | P2 |
| Data export | LOW | MEDIUM | P3 |
| Data cap alerts | LOW | HIGH | P3 |
| Keyboard shortcut | LOW | LOW | P3 |

**Priority key:**
- P1: Must have for launch -- core monitoring + display + basic UX
- P2: Should have, add when possible -- persistence + history (the differentiator)
- P3: Nice to have, future consideration

## Competitor Feature Analysis

| Feature | iStat Menus 7 ($12/yr) | PeakHour ($12/yr or $45) | Stats (Free/OSS) | Bandwidth+ ($1 one-time) | Scaler (Free) | Our Approach |
|---------|------------------------|--------------------------|-------------------|--------------------------|---------------|--------------|
| Real-time speed in menu bar | Yes, highly customizable | Yes | Yes | Yes (4 display modes) | Yes | Yes, with format options |
| Per-interface monitoring | Yes | Yes | Yes | Limited | No | Yes, in popover |
| Historical data persistence | Yes (in-app) | Yes (powerful history view) | No (resets on quit) | Monthly tracking only | No | Yes, SQLite with multi-timeframe |
| Time-range charts | Yes (limited) | Yes (best in class) | No | No | Recent only | Yes (hour/day/week/month) |
| Per-app bandwidth | Yes (via nettop) | No | No | No | No | No (link to Activity Monitor) |
| Data cap alerts | No | Yes | No | Yes (monthly quota) | No | No (v1), maybe v2 |
| Launch at login | Yes | Yes | Yes | Yes | Not documented | Yes |
| Sparkline/mini-graph in bar | Yes | Yes | Yes (multiple styles) | No | Yes (activity chart) | Yes (optional) |
| Export data | No | Yes (CSV) | No | Yes (RTF) | No | No (v1), maybe v2 |
| Resource usage | Very low | Low-moderate | Very low | Very low | Very low | Target < 1% CPU |
| Price | $12/year subscription | $12/yr or $45 one-time | Free | $1 one-time | Free | Free |
| Open source | No | No | Yes | No | No | Yes |

**Competitive positioning:** The gap in the market is a free, open-source app that combines the always-on lightweight monitoring of Stats/Scaler with the historical data persistence and beautiful charts that only PeakHour offers behind a paywall. iStat Menus is the premium all-in-one; we are the focused, free, network-only alternative with history.

## Sources

- [iStat Menus](https://bjango.com/mac/istatmenus/) -- Feature reference for premium competitor
- [Stats (exelban)](https://github.com/exelban/stats) -- Open-source menu bar monitor reference
- [PeakHour](https://peakhourapp.com/) -- Bandwidth history and alerting feature reference
- [Bandwidth+](https://apps.apple.com/us/app/bandwidth/id490461369?mt=12) -- Lightweight menu bar bandwidth tracker
- [Scaler Bandwidth Monitor](https://apps.apple.com/us/app/scaler-bandwidth-monitor/id1612708557) -- Minimal free bandwidth monitor
- [NetSpeedMonitorPro](https://github.com/tengfeihe/NetSpeedMonitorPro) -- Technical reference for sysctl-based monitoring approach
- [NetSpeedMonitor](https://github.com/elegracer/NetSpeedMonitor) -- Open-source SwiftUI menu bar speed monitor
- [Apple HIG: Menu Bar](https://developer.apple.com/design/human-interface-guidelines/the-menu-bar) -- Design guidelines for menu bar extras
- [macos-bandwidth-monitor](https://github.com/dhanushreddy291/macos-bandwidth-monitor) -- Minimal open-source reference

---
*Feature research for: macOS menu bar bandwidth monitor*
*Researched: 2026-03-23*
