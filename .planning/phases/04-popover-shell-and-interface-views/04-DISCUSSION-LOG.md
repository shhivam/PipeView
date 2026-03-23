# Phase 4: Popover Shell and Interface Views - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-03-24
**Phase:** 04-popover-shell-and-interface-views
**Areas discussed:** Click behavior, Interface breakdown layout, Popover structure, Visual style

---

## Click Behavior

| Option | Description | Selected |
|--------|-------------|----------|
| Left-click → popover | Left-click opens popover directly. Right-click opens context menu. Standard macOS pattern | ✓ (with modifications) |
| Menu item trigger | Both clicks open NSMenu. 'Metrics' item opens popover | |
| Left-click → popover, no separate menu | Popover with gear button, no separate context menu | |

**User's choice:** Left-click → popover, but right-click should show Quit, Preferences, About, Metrics. The popover has two tabs: Preferences and Metrics.
**Notes:** User wants the popover to be the primary interaction with tabbed content, and the context menu as a secondary access path.

### Follow-up: Menu item deep links

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, open to that tab | Clicking 'Metrics' or 'Preferences' in menu opens popover to that specific tab | ✓ |
| Just open the popover | Both items open popover to last active tab | |

**User's choice:** Yes, open to that tab
**Notes:** None

### Follow-up: Preferences tab timing

| Option | Description | Selected |
|--------|-------------|----------|
| Placeholder tab now | Add both tabs in Phase 4. Preferences tab shows placeholder. Phase 5 fills it in | ✓ |
| Metrics tab only | Phase 4 only has Metrics. Phase 5 adds tab bar and Preferences | |

**User's choice:** Placeholder tab now
**Notes:** Establishes tab structure early for Phase 5 to build on

---

## Interface Breakdown Layout

| Option | Description | Selected |
|--------|-------------|----------|
| Simple rows | Row per interface: icon + name left, speeds right. Compact, like Activity Monitor | ✓ |
| Cards per interface | Card/tile per interface with name, type, speeds | |
| Compact table | Header row + data rows, spreadsheet-like | |

**User's choice:** Simple rows
**Notes:** None

### Follow-up: Row content

| Option | Description | Selected |
|--------|-------------|----------|
| Icon + name + speeds | SF Symbol + display name + upload/download speed | ✓ |
| Name + speeds only | Display name and speeds, no icon | |
| Icon + name + speeds + total | All above plus cumulative total transferred today | |

**User's choice:** Icon + name + speeds
**Notes:** None

### Follow-up: Speed format consistency

| Option | Description | Selected |
|--------|-------------|----------|
| Same format as menu bar | Reuse SpeedFormatter, consistent experience | |
| More detailed in popover | Always show both upload and download per interface regardless of menu bar mode | ✓ |
| You decide | Claude's discretion | |

**User's choice:** More detailed in popover
**Notes:** Menu bar is the summary, popover is the detail view

---

## Popover Structure

| Option | Description | Selected |
|--------|-------------|----------|
| Aggregate header | Top section shows combined total, per-interface list below | ✓ |
| Interfaces only | Just per-interface list, no aggregate section | |
| You decide | Claude's discretion | |

**User's choice:** Aggregate header
**Notes:** Quick summary before the per-interface detail

### Follow-up: Quit button placement

| Option | Description | Selected |
|--------|-------------|----------|
| Bottom footer bar | Subtle footer row at bottom of popover | |
| No quit in popover | Quit only via right-click context menu | ✓ |
| Inside gear/settings menu | Small gear icon in popover header | |

**User's choice:** No quit in popover
**Notes:** Deliberate deviation from POP-06. Right-click context menu provides quit access. Keeps popover focused on content.

### Follow-up: Tab bar style

| Option | Description | Selected |
|--------|-------------|----------|
| Segmented control at top | SwiftUI Picker with .segmented style. Native macOS look | ✓ |
| Sidebar tabs | Vertical tab list on left side | |
| You decide | Claude's discretion | |

**User's choice:** Segmented control at top
**Notes:** None

---

## Visual Style

| Option | Description | Selected |
|--------|-------------|----------|
| Clean and spacious | Generous padding, clear hierarchy, breathing room | ✓ |
| Compact and dense | Tight spacing, more data visible, Activity Monitor feel | |
| You decide | Claude's discretion | |

**User's choice:** Clean and spacious
**Notes:** None

### Follow-up: Interface type icons

| Option | Description | Selected |
|--------|-------------|----------|
| SF Symbols | wifi, cable.connector.horizontal, lock.shield, network | ✓ |
| No icons, text only | Just display names | |
| Colored dots by type | Small colored circles by type | |

**User's choice:** SF Symbols
**Notes:** None

### Follow-up: Color palette

| Option | Description | Selected |
|--------|-------------|----------|
| Semantic colors only | SwiftUI .primary, .secondary, .accentColor, system backgrounds | ✓ |
| Upload green / Download blue | Semantic backgrounds but tinted speed values | |
| You decide | Claude's discretion | |

**User's choice:** Semantic colors only
**Notes:** Zero custom colors, automatic dark/light mode adaptation

---

## Claude's Discretion

- NSPopover configuration (behavior, appearance, animation)
- Left-click vs right-click handling on NSStatusItem
- Exact spacing, padding, and font sizes
- NetworkMonitor to SwiftUI data bridging approach
- Tab state management for menu item navigation
- Empty state presentation
- ScrollView behavior for many interfaces

## Deferred Ideas

None — discussion stayed within phase scope
