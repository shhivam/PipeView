# Requirements: Bandwidth Monitor

**Defined:** 2026-03-23
**Core Value:** Reliable, always-visible network throughput monitoring — glance at the menu bar for current speeds, open the popover for usage patterns over time

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Monitoring

- [x] **MON-01**: App measures real-time upload and download throughput per network interface using sysctl
- [x] **MON-02**: App identifies and enumerates active network interfaces (Wi-Fi, Ethernet, VPN tunnels) filtering loopback and inactive
- [x] **MON-03**: App records bandwidth samples to SQLite at regular intervals
- [x] **MON-04**: App aggregates raw samples into minute, hour, day, week, and month granularity tiers
- [x] **MON-05**: App prunes old raw samples while preserving aggregated data to keep database bounded
- [x] **MON-06**: App uses less than 1% CPU and minimal RAM during normal operation

### Menu Bar Display

- [ ] **BAR-01**: Menu bar shows current upload and download speed as text (e.g. ↑ 1.2 MB/s ↓ 45 KB/s)
- [ ] **BAR-02**: User can select preferred display unit (auto-scale, KB/s, MB/s, Gb/s) in preferences
- [ ] **BAR-03**: User can configure display format (upload+download, download only, upload only, combined total) in preferences
- [ ] **BAR-04**: Menu bar text uses fixed-width formatting to prevent jitter when values change

### Popover UI

- [x] **POP-01**: Clicking the menu bar item opens a medium-sized popover window (~400x500px)
- [ ] **POP-02**: Popover shows historical bar/area charts with switchable time ranges (hour, day, week, month)
- [x] **POP-03**: Popover shows per-interface bandwidth breakdown with individual stats
- [ ] **POP-04**: Popover shows cumulative statistics (total data today, this week, this month)
- [x] **POP-05**: Popover supports dark mode and light mode automatically
- [ ] **POP-06**: Popover includes a quit button

### System Integration

- [ ] **SYS-01**: App registers as a login item and starts automatically when macOS boots (SMAppService)
- [ ] **SYS-02**: App provides a preferences/settings interface for configuring display options and update interval

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Enhanced Display

- **ENH-01**: Inline sparkline mini-graph in the menu bar next to speed text
- **ENH-02**: Configurable update interval (1s, 2s, 5s) exposed in preferences
- **ENH-03**: Recent real-time activity line/area chart (last 5-10 minutes at 1-second granularity)

### Data Management

- **DAT-01**: Data export to CSV or JSON
- **DAT-02**: Data cap monitoring with alerts when approaching user-set limits

### Polish

- **POL-01**: Customizable chart colors/themes
- **POL-02**: Keyboard shortcut to toggle popover
- **POL-03**: Custom menu bar icon options

## Out of Scope

| Feature | Reason |
|---------|--------|
| Per-application bandwidth breakdown | Requires nettop/Network Extension, pushes CPU from <1% to 5-15% — undermines core value |
| Speed test (Speedtest.net style) | Different product category; measures max capability, not actual throughput |
| Cloud sync / multi-device | Massive scope increase (CloudKit, conflict resolution); local-only tool |
| Network diagnostics / traceroute | Different product category; users have terminal for this |
| macOS widgets | WidgetKit refreshes every 5-15 min — misleading for real-time data; menu bar IS the widget |
| VPN-specific features | Per-interface view naturally shows utun interfaces without VPN-specific logic |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| MON-01 | Phase 1: Core Monitoring Engine | Complete |
| MON-02 | Phase 1: Core Monitoring Engine | Complete |
| MON-03 | Phase 3: Data Persistence and Aggregation | Complete |
| MON-04 | Phase 3: Data Persistence and Aggregation | Complete |
| MON-05 | Phase 3: Data Persistence and Aggregation | Complete |
| MON-06 | Phase 1: Core Monitoring Engine | Complete |
| BAR-01 | Phase 2: Menu Bar Display | Pending |
| BAR-02 | Phase 2: Menu Bar Display | Pending |
| BAR-03 | Phase 2: Menu Bar Display | Pending |
| BAR-04 | Phase 2: Menu Bar Display | Pending |
| POP-01 | Phase 4: Popover Shell and Interface Views | Complete |
| POP-02 | Phase 5: Historical Charts, Statistics, and Settings | Pending |
| POP-03 | Phase 4: Popover Shell and Interface Views | Complete |
| POP-04 | Phase 5: Historical Charts, Statistics, and Settings | Pending |
| POP-05 | Phase 4: Popover Shell and Interface Views | Complete |
| POP-06 | Phase 4: Popover Shell and Interface Views | Pending |
| SYS-01 | Phase 2: Menu Bar Display | Pending |
| SYS-02 | Phase 5: Historical Charts, Statistics, and Settings | Pending |

**Coverage:**
- v1 requirements: 18 total
- Mapped to phases: 18
- Unmapped: 0

---
*Requirements defined: 2026-03-23*
*Last updated: 2026-03-23 after roadmap creation*
