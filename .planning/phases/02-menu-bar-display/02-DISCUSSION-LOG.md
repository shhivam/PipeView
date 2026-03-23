# Phase 2: Menu Bar Display - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-03-23
**Phase:** 02-Menu Bar Display
**Areas discussed:** Speed text format, Auto-scale thresholds, Right-click menu, Preferences access, Menu bar icon, First launch experience, Disconnected state

---

## Speed Text Format

### Arrow symbols
| Option | Description | Selected |
|--------|-------------|----------|
| ↑ ↓ (Unicode arrows) | Clean and minimal, widely used in network monitors | ✓ |
| ▲ ▼ (Filled triangles) | More visually prominent at small sizes | |
| ⬆ ⬇ (Bold arrows) | Thick arrows, very visible | |

**User's choice:** ↑ ↓ Unicode arrows

### Precision
| Option | Description | Selected |
|--------|-------------|----------|
| 1 decimal always | Compact and consistent | |
| Adaptive (0-1 decimals) | 1 decimal below 100, no decimal at 100+ | ✓ |
| 2 decimals always | More precise but wider | |

**User's choice:** Adaptive precision

### Unit labels
| Option | Description | Selected |
|--------|-------------|----------|
| MB/s, KB/s, GB/s | Base-10 SI bytes, standard for network throughput | ✓ |
| MiB/s, KiB/s, GiB/s | Binary units, technically precise but uncommon for network | |
| Mbps, Kbps, Gbps | Bits per second, ISP convention | |

**User's choice:** MB/s, KB/s, GB/s (base-10 SI)

### Anti-jitter
| Option | Description | Selected |
|--------|-------------|----------|
| Monospaced font + fixed padding | SF Mono/Menlo, right-aligned | |
| Proportional font with tabular figures | SF Pro with .monospacedDigit() | ✓ |
| You decide | Claude picks | |

**User's choice:** Proportional font with tabular figures (SF Pro + .monospacedDigit())

### Separator (upload+download)
| Option | Description | Selected |
|--------|-------------|----------|
| Space only | Compact | ✓ |
| Double space | More readable | |
| Vertical bar | Explicit separation | |

**User's choice:** Space only
**Notes:** User clarified they want single speed displayed at a time, not both. Led to display mode discussion.

### Display mode
| Option | Description | Selected |
|--------|-------------|----------|
| Auto-rotate on timer | Alternate every N seconds | |
| Show whichever is higher | Arrow indicates dominant direction | ✓ |
| Download default, flash upload | Download normally, flash upload on activity | |
| User picks one in prefs | Static choice in preferences | |

**User's choice:** Show whichever is higher
**Notes:** User wants single metric visible by default, with the arrow indicating direction.

### Display format override
| Option | Description | Selected |
|--------|-------------|----------|
| "Higher wins" is the only mode | No config | |
| "Higher wins" default + override in prefs | Three modes | |
| Three modes in prefs | Auto, Upload only, Download only | |

**User's choice:** Other — Four modes: Auto (higher wins, default), Upload only, Download only, Both together. User explicitly wanted "Both" as an option too.

---

## Auto-Scale Thresholds

### Scale base
| Option | Description | Selected |
|--------|-------------|----------|
| Base-10 / SI | KB/s at 1,000 B/s, MB/s at 1,000,000 | ✓ |
| Base-2 / binary | KB/s at 1,024 B/s, MB/s at 1,048,576 | |

**User's choice:** Base-10 SI

### Idle display
| Option | Description | Selected |
|--------|-------------|----------|
| Show "0 KB/s" | Always show a value | ✓ |
| Show "—" or idle indicator | Dash when below threshold | |
| Show actual B/s value | Precise but noisy | |

**User's choice:** Show "0 KB/s"

### Fixed unit fallback
| Option | Description | Selected |
|--------|-------------|----------|
| Show 0.0 MB/s for tiny values | Strictly honor chosen unit | |
| Fall back to smaller unit | Ceiling behavior, preserve precision | ✓ |

**User's choice:** Fall back to smaller unit

---

## Right-Click Menu

### Menu items
**User's choice (multi-select + free text):** Quit, About, plus Preferences and Metrics options (both disabled "Coming soon" in Phase 2)

### Placeholder behavior
| Option | Description | Selected |
|--------|-------------|----------|
| Disabled/grayed out with "Coming soon" | Visible but disabled | ✓ |
| Don't show until Phase 4/5 | Only Quit + About | |
| Minimal preferences window now | Basic settings window | |

**User's choice:** Disabled with "Coming soon"

### Left-click behavior
| Option | Description | Selected |
|--------|-------------|----------|
| Left-click = same menu (for now) | Both clicks open menu, Phase 4 changes left-click | |
| Left-click = nothing (for now) | Reserved for future popover | |
| Left-click = menu, right-click = menu | Identical forever, popover from menu item | ✓ |

**User's choice:** Both clicks open same menu permanently. Popover accessed via Metrics menu item.

---

## Preferences Access

| Option | Description | Selected |
|--------|-------------|----------|
| Hardcode defaults, defer to Phase 5 | No config in Phase 2 | ✓ |
| Minimal preferences window now | Small SwiftUI window | |
| Inline submenus in right-click menu | Quick access submenus | |

**User's choice:** Defer all preferences to Phase 5. Defaults: Auto-scale + Auto (higher wins).

---

## Menu Bar Icon

| Option | Description | Selected |
|--------|-------------|----------|
| Text only — no icon | Arrows serve as identifier | ✓ |
| Small icon + text | Network icon alongside speed | |
| Icon when idle, text when active | Context-dependent | |

**User's choice:** Text only, no icon

---

## First Launch Experience

| Option | Description | Selected |
|--------|-------------|----------|
| Straight to menu bar | No onboarding | ✓ |
| Brief welcome tooltip | Auto-dismiss info popover | |
| Setup wizard window | Pick settings before starting | |

**User's choice:** Straight to menu bar

### Login item registration
| Option | Description | Selected |
|--------|-------------|----------|
| Auto-register on first launch | SMAppService, no prompt | ✓ |
| Ask user on first launch | One-time dialog | |
| Off by default | User enables manually | |

**User's choice:** Auto-register via SMAppService

---

## Disconnected State

### Display
| Option | Description | Selected |
|--------|-------------|----------|
| Show ↓ 0 KB/s | Same as idle | |
| Show "no connection" indicator | Dash or offline text | ✓ |
| Hide menu bar item entirely | Remove when disconnected | |

**User's choice:** No connection indicator

### Specific text
| Option | Description | Selected |
|--------|-------------|----------|
| — (em dash) | Minimal | ✓ |
| No Network | Explicit text | |
| You decide | Claude picks | |

**User's choice:** Em dash (—)

---

## Claude's Discretion

- NSMenu construction details and item ordering refinements
- Exact spacing/padding in status bar text string
- NetworkMonitor → NSStatusItem bridging approach
- AppDelegate vs SwiftUI App lifecycle integration
- SMAppService error handling
- About window content and layout

## Deferred Ideas

- Multi-interface pin (show specific interface vs aggregate) — Phase 5 preferences
- Display format/unit submenus in right-click menu — deferred to Phase 5
- Mbps (bits) unit option — could add in Phase 5
