# Phase 1: Core Monitoring Engine - Context

**Gathered:** 2026-03-23
**Status:** Ready for planning

<domain>
## Phase Boundary

Accurate real-time per-interface network throughput measurement with energy-efficient polling. The engine reads byte counters via sysctl, computes upload/download speeds, detects active interfaces, and exposes per-interface and aggregate speed data. No UI, no persistence, no menu bar display — just the measurement foundation that all downstream phases build on.

</domain>

<decisions>
## Implementation Decisions

### Polling Interval
- **D-01:** Default polling interval is 2 seconds — balances responsiveness with energy efficiency
- **D-02:** Interval is configurable internally (parameter, not hardcoded constant) so Phase 5 preferences can expose 1s/2s/5s options later

### Speed Calculation
- **D-03:** Raw byte delta per interval — exact bytes transferred since last sample, divided by elapsed time. No smoothing or averaging at the engine level
- **D-04:** Counter resets (new counter value < previous) report zero for that sample — skip and move on, avoids false spikes

### Interface Filtering
- **D-05:** Track physical interfaces (Wi-Fi, Ethernet, Cellular) plus VPN tunnels (utun). Filter out loopback (lo0), bridge interfaces, and virtual adapters (vnic, vmnet for Docker/Parallels)
- **D-06:** NWPathMonitor as primary interface change detection (event-driven, immediate) plus re-enumerate the interface list on each poll cycle as a safety net — never misses a change
- **D-07:** Resolve BSD names to human-readable names in the engine using SystemConfiguration (en0 -> "Wi-Fi", en1 -> "Ethernet"). Downstream phases display friendly names directly

### Aggregate Totals
- **D-08:** Engine computes both per-interface speeds AND a summed total across all active interfaces. Phase 2 menu bar can show the total without re-computing

### Sleep/Wake Behavior
- **D-09:** Detect wake via NSWorkspace notifications. Discard the first post-wake byte delta (it spans the entire sleep period and would show a false spike). Resume normal 2s polling after

### Error Resilience
- **D-10:** Skip failed sysctl samples silently, log at debug level (os_log). After 5+ consecutive failures, log a warning. Do not surface errors to UI — a single missed 2s sample is invisible to the user

### Claude's Discretion
- Internal data model / struct design for speed samples
- Actor vs class vs protocol architecture for the monitoring engine
- Memory management for the polling loop
- Exact os_log categories and levels
- Task.sleep tolerance value for energy efficiency
- Debounce duration for NWPathMonitor rapid events

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

No external specs or ADRs — requirements fully captured in decisions above.

### Tech Stack Reference
- `CLAUDE.md` — Full technology stack decisions, API choices (sysctl IFMIB_IFDATA, NWPathMonitor, SystemConfiguration), version requirements, and alternatives considered

### Requirements
- `.planning/REQUIREMENTS.md` — MON-01 (per-interface throughput), MON-02 (interface enumeration), MON-06 (< 1% CPU)

### Known Risks
- `.planning/STATE.md` §Blockers/Concerns — sysctl IFMIB_IFDATA stability risk, App Sandbox compatibility uncertainty

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- None — greenfield project, this is the first phase

### Established Patterns
- None yet — patterns established here will be carried forward to all subsequent phases

### Integration Points
- This engine is the foundation layer. Phase 2 (Menu Bar Display) will consume the speed data published by this engine
- Phase 3 (Data Persistence) will subscribe to speed samples for SQLite storage

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-core-monitoring-engine*
*Context gathered: 2026-03-23*
