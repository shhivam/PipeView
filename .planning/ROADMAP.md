# Roadmap: Bandwidth Monitor

## Milestones

- ✅ **v1.0 MVP** — Phases 1-7 (shipped 2026-03-24)
- 🚧 **v1.1 UI Polish & Chart Fixes** — Phases 8-9 (in progress)

## Phases

<details>
<summary>✅ v1.0 MVP (Phases 1-7) — SHIPPED 2026-03-24</summary>

- [x] Phase 1: Core Monitoring Engine (2/2 plans) — completed 2026-03-23
- [x] Phase 2: Menu Bar Display (2/2 plans) — completed 2026-03-23
- [x] Phase 3: Data Persistence and Aggregation (3/3 plans) — completed 2026-03-23
- [x] Phase 4: Popover Shell and Interface Views (2/2 plans) — completed 2026-03-24
- [x] Phase 5: Historical Charts, Statistics, and Settings (3/3 plans) — completed 2026-03-24
- [x] Phase 6: Fix Polling Interval Sync (1/1 plan) — completed 2026-03-24
- [x] Phase 7: Verification and Artifact Cleanup (1/1 plan) — completed 2026-03-24

Full details: `.planning/milestones/v1.0-ROADMAP.md`

</details>

### 🚧 v1.1 UI Polish & Chart Fixes (In Progress)

**Milestone Goal:** Improve the popover UI -- combine tabs, fix chart rendering issues, and upgrade to a floating panel window for more space.

- [ ] **Phase 8: Panel & Tab Restructure** - Replace NSPopover with floating utility panel and merge Metrics + History into a single combined tab
- [ ] **Phase 9: Chart Fixes & Layout Polish** - Fix chart hover, 7D/30D bar grouping, y-axis formatting, and stat card text layout

## Phase Details

### Phase 8: Panel & Tab Restructure
**Goal**: Users interact with the app through a floating utility panel containing a single unified tab that shows both live speeds and historical data
**Depends on**: Phase 7 (v1.0 complete)
**Requirements**: UIST-01, UIST-02
**Success Criteria** (what must be TRUE):
  1. Clicking the menu bar icon opens a floating utility panel (not an NSPopover) that stays on top of other windows
  2. The floating panel dismisses when the user clicks outside it or switches focus to another application
  3. The user sees a single combined view with live per-interface speeds at the top and history charts + cumulative stats below, without needing to switch tabs
  4. The tab bar no longer shows separate "Metrics" and "History" tabs (only the combined view and Preferences remain)
**Plans:** 2 plans
Plans:
- [x] 08-01-PLAN.md — Merge tabs into Dashboard view (PopoverTab enum, DashboardView, PopoverContentView, tests)
- [ ] 08-02-PLAN.md — Replace NSPopover with floating panel (FloatingPanel, StatusBarController, context menu)
**UI hint**: yes

### Phase 9: Chart Fixes & Layout Polish
**Goal**: Charts render correctly across all time ranges with readable axes and proper interaction, and stat cards display without layout issues
**Depends on**: Phase 8
**Requirements**: CHRT-01, CHRT-02, CHRT-03, CHRT-04, LYOT-01
**Success Criteria** (what must be TRUE):
  1. User can hover over or select any bar in the chart without the y-axis shifting, compressing, or the chart layout changing
  2. The 7D view shows exactly 7 bars (one per day) with day-of-week labels (Mon, Tue, Wed, etc.)
  3. The 30D view shows one bar per day with readable date labels
  4. Y-axis labels display human-readable units (auto-scaled KB, MB, or GB) instead of raw byte values
  5. Stat card text for Today, This Week, and This Month is fully visible without truncation or wrapping
**Plans**: TBD
**UI hint**: yes

## Progress

**Execution Order:**
Phases execute in numeric order: 8 -> 9

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Core Monitoring Engine | v1.0 | 2/2 | Complete | 2026-03-23 |
| 2. Menu Bar Display | v1.0 | 2/2 | Complete | 2026-03-23 |
| 3. Data Persistence and Aggregation | v1.0 | 3/3 | Complete | 2026-03-23 |
| 4. Popover Shell and Interface Views | v1.0 | 2/2 | Complete | 2026-03-24 |
| 5. Historical Charts, Statistics, and Settings | v1.0 | 3/3 | Complete | 2026-03-24 |
| 6. Fix Polling Interval Sync | v1.0 | 1/1 | Complete | 2026-03-24 |
| 7. Verification and Artifact Cleanup | v1.0 | 1/1 | Complete | 2026-03-24 |
| 8. Panel & Tab Restructure | v1.1 | 0/2 | Planning | - |
| 9. Chart Fixes & Layout Polish | v1.1 | 0/0 | Not started | - |
