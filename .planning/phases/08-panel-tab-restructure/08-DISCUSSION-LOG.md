# Phase 8: Panel & Tab Restructure - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-03-24
**Phase:** 08-panel-tab-restructure
**Areas discussed:** Panel positioning & behavior, Combined view layout, Tab bar & navigation, Panel sizing

---

## Panel positioning & behavior

### Panel origin

| Option | Description | Selected |
|--------|-------------|----------|
| Anchored below status item (Recommended) | Panel drops down from menu bar aligned to status item — same as current popover | |
| Screen-center floating | Panel appears centered on active screen, detached from menu bar | ✓ |

**User's choice:** Screen-center floating
**Notes:** None

### Dismiss behavior

| Option | Description | Selected |
|--------|-------------|----------|
| Click outside or focus loss (Recommended) | Panel closes on outside click or app switch. Matches SC-2 and current .transient behavior | ✓ |
| Only on explicit close | Stays open until close button or Escape | |
| Click outside OR close button | Both auto-dismiss and visible close button | |

**User's choice:** Click outside or focus loss (Recommended)
**Notes:** None

### Animation

| Option | Description | Selected |
|--------|-------------|----------|
| Fade in/out (Recommended) | Subtle opacity transition | |
| No animation | Instant appear/disappear | ✓ |
| You decide | Claude picks | |

**User's choice:** No animation
**Notes:** None

---

## Combined view layout

### Arrangement

| Option | Description | Selected |
|--------|-------------|----------|
| Live at top, history below (Recommended) | Aggregate header + per-interface speeds at top, time range picker + chart + stats below | ✓ |
| Compact live header, history dominant | Minimal single-line aggregate at top, expandable per-interface, chart dominant | |
| Side by side | Live speeds left, history right. Requires wider window | |

**User's choice:** Live at top, history below (Recommended)
**Notes:** None

### Visual separation

| Option | Description | Selected |
|--------|-------------|----------|
| Subtle divider line (Recommended) | Thin Divider() between sections | ✓ |
| Spacing only | Extra vertical padding, no explicit line | |
| You decide | Claude picks | |

**User's choice:** Subtle divider line (Recommended)
**Notes:** None

### Scroll behavior

| Option | Description | Selected |
|--------|-------------|----------|
| Entire view scrolls (Recommended) | One ScrollView wraps everything | ✓ |
| Fixed header, rest scrolls | Aggregate header pinned, rest scrolls | |
| You decide | Claude picks | |

**User's choice:** Entire view scrolls (Recommended)
**Notes:** None

---

## Tab bar & navigation

### Tab structure

| Option | Description | Selected |
|--------|-------------|----------|
| Remove tab bar, gear icon for Preferences (Recommended) | No segmented control. Gear icon in top-right opens Preferences | |
| Keep 2-tab segmented control | Dashboard and Preferences tabs. Consistent with existing pattern | ✓ |
| No Preferences in panel | Move Preferences to right-click only | |

**User's choice:** Keep 2-tab segmented control
**Notes:** None

### Context menu

| Option | Description | Selected |
|--------|-------------|----------|
| Dashboard + Preferences (Recommended) | Replace Metrics/History with single Dashboard item | ✓ |
| Just Preferences + Quit | Remove Dashboard from menu, left-click already opens it | |
| You decide | Claude adapts menu to match tab structure | |

**User's choice:** Dashboard + Preferences (Recommended)
**Notes:** None

---

## Panel sizing

### Dimensions

| Option | Description | Selected |
|--------|-------------|----------|
| Keep 400x550, scroll if needed (Recommended) | Same footprint as current popover | |
| Taller: 400x650 | Same width, 100px taller | |
| Wider and taller: 480x650 | More room for charts and stat cards | ✓ |

**User's choice:** Wider and taller: 480x650
**Notes:** None

---

## Claude's Discretion

- Exact always-on-top window level (NSWindow.Level)
- NSPanel vs NSWindow subclass choice
- Screen centering calculation
- Internal spacing and padding adjustments

## Deferred Ideas

None — discussion stayed within phase scope.
