# Requirements: Bandwidth Monitor

**Defined:** 2026-03-24
**Core Value:** Reliable, always-visible network throughput monitoring — the user can glance at the menu bar and instantly know their current upload/download speeds, and open the popover to understand usage patterns over time.

## v1.1 Requirements

Requirements for v1.1 UI Polish & Chart Fixes. Each maps to roadmap phases.

### UI Structure

- [x] **UIST-01**: User sees a single "Metrics" tab combining live interface speeds and history charts in one scrollable view
- [ ] **UIST-02**: User interacts with a floating utility panel instead of a popover (stays on top, dismisses on focus loss)

### Charts

- [ ] **CHRT-01**: User can hover/select a chart bar without the y-axis shifting or the chart compressing
- [ ] **CHRT-02**: User sees one bar per day with day labels (Mon, Tue, etc.) in the 7D view
- [ ] **CHRT-03**: User sees one bar per day with day labels in the 30D view
- [ ] **CHRT-04**: User sees human-readable y-axis labels (auto-scaled KB/MB/GB) instead of raw bytes

### Layout

- [ ] **LYOT-01**: User sees stat card text (Today, This Week, This Month) fully visible without truncation or wrapping

## Future Requirements

None deferred — all identified items are in v1.1 scope.

## Out of Scope

| Feature | Reason |
|---------|--------|
| New data layer changes | v1.1 is UI-only; monitoring and persistence unchanged |
| Per-app bandwidth breakdown | Still excluded — CPU cost too high |
| Data cap alerts / notifications | Deferred beyond v1.1 |
| Resizable/draggable window | Floating panel is fixed-position utility window for v1.1 |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| UIST-01 | Phase 8 | Complete |
| UIST-02 | Phase 8 | Pending |
| CHRT-01 | Phase 9 | Pending |
| CHRT-02 | Phase 9 | Pending |
| CHRT-03 | Phase 9 | Pending |
| CHRT-04 | Phase 9 | Pending |
| LYOT-01 | Phase 9 | Pending |

**Coverage:**
- v1.1 requirements: 7 total
- Mapped to phases: 7
- Unmapped: 0

---
*Requirements defined: 2026-03-24*
*Last updated: 2026-03-24 after roadmap creation*
