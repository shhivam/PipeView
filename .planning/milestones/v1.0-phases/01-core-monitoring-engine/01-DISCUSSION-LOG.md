# Phase 1: Core Monitoring Engine - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-03-23
**Phase:** 01-Core Monitoring Engine
**Areas discussed:** Polling interval, Speed smoothing, Interface filtering, Aggregate totals, Sleep/wake behavior, Error resilience

---

## Polling Interval

| Option | Description | Selected |
|--------|-------------|----------|
| 1 second | Matches Activity Monitor feel. Most responsive. At <1% CPU target achievable with sysctl + Task.sleep tolerance. | |
| 2 seconds | More energy efficient. Still feels real-time. Better for laptops on battery. | ✓ |
| Adaptive | 1s when on power, 2s on battery. More complex but best of both worlds. | |

**User's choice:** 2 seconds
**Notes:** None

| Option | Description | Selected |
|--------|-------------|----------|
| Configurable | Engine accepts an interval parameter internally. Phase 5 preferences can expose it later (1s/2s/5s). | ✓ |
| Fixed at 2s | Hardcode 2s. Simpler. Can refactor later if needed. | |

**User's choice:** Configurable (engine accepts interval parameter)
**Notes:** None

---

## Speed Smoothing

| Option | Description | Selected |
|--------|-------------|----------|
| Raw delta | Report exact bytes transferred since last sample, divided by interval. Accurate and simple. May look jumpy for bursty traffic. | ✓ |
| Exponential moving average | Smooth values over ~3-5 samples. Stable display like Activity Monitor. Slightly laggy. | |
| Both layers | Engine reports raw deltas. Separate smoothing layer for UI consumption. Most flexible. | |

**User's choice:** Raw delta
**Notes:** None

| Option | Description | Selected |
|--------|-------------|----------|
| Skip and report zero | If new counter < previous counter, report 0. Simple, avoids false spikes. Misses at most one sample. | ✓ |
| You decide | Let Claude pick during implementation. | |

**User's choice:** Skip and report zero on counter reset
**Notes:** None

---

## Interface Filtering

| Option | Description | Selected |
|--------|-------------|----------|
| Physical + VPN | Wi-Fi, Ethernet, Cellular, plus VPN tunnels (utun). Filter out loopback, bridge, virtual adapters. | ✓ |
| Physical only | Just Wi-Fi, Ethernet, Cellular. VPN traffic captured indirectly through physical interface. | |
| Everything non-loopback | Show all interfaces except lo0. Includes Docker, Parallels, etc. | |

**User's choice:** Physical + VPN
**Notes:** None

| Option | Description | Selected |
|--------|-------------|----------|
| NWPathMonitor + verify on poll | React to system events + re-check interface list each poll as safety net. Most robust. | ✓ |
| NWPathMonitor only | Pure event-driven. Lighter, but could miss a delayed notification. | |
| Re-enumerate each poll only | Check full interface list every 2s. Simple, up to 2s delay. | |
| You decide | Let Claude pick during implementation. | |

**User's choice:** NWPathMonitor + verify on poll
**Notes:** User asked about NWPathMonitor reliability. Confirmed it's Apple's official API, very reliable, but can fire multiple rapid events for a single change (needs debounce). Combined approach is most robust.

| Option | Description | Selected |
|--------|-------------|----------|
| Resolve now | Use SystemConfiguration to map BSD names to friendly names in the engine. | ✓ |
| Defer to UI | Engine reports raw BSD names, UI phases map to friendly names. | |

**User's choice:** Resolve names in the engine now
**Notes:** None

---

## Aggregate Totals

| Option | Description | Selected |
|--------|-------------|----------|
| Per-interface + total | Engine provides both individual interface speeds AND a summed total. | ✓ |
| Per-interface only | Engine only reports individual interfaces. Downstream consumers sum if needed. | |
| You decide | Let Claude pick during implementation. | |

**User's choice:** Per-interface + total
**Notes:** None

---

## Sleep/Wake Behavior

| Option | Description | Selected |
|--------|-------------|----------|
| Detect wake, skip gap | Listen for NSWorkspace wake notifications. Discard first post-wake delta. Resume normal polling. | ✓ |
| Pause timer on sleep | Suspend polling timer during sleep. Normalize first post-wake sample by actual elapsed time. | |
| You decide | Let Claude pick during implementation. | |

**User's choice:** Detect wake, skip gap
**Notes:** None

---

## Error Resilience

| Option | Description | Selected |
|--------|-------------|----------|
| Skip silently, log debug | Skip failed sample, log at debug level. After 5+ consecutive failures, log warning. Don't surface to UI. | ✓ |
| Surface to UI | Report errors upstream for warning icon. More transparent but adds API complexity. | |
| You decide | Let Claude pick during implementation. | |

**User's choice:** Skip silently, log debug
**Notes:** None

---

## Claude's Discretion

- Internal data model / struct design
- Actor vs class architecture
- Memory management for polling loop
- os_log categories and levels
- Task.sleep tolerance value
- NWPathMonitor debounce duration

## Deferred Ideas

None — discussion stayed within phase scope
