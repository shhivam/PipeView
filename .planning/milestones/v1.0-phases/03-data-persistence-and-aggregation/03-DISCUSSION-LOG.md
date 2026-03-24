# Phase 3: Data Persistence and Aggregation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-03-24
**Phase:** 03-data-persistence-and-aggregation
**Areas discussed:** Recording strategy, Aggregation timing, Retention & pruning, Data granularity

---

## Recording Strategy

### Recording Interval

| Option | Description | Selected |
|--------|-------------|----------|
| Every poll cycle (2s) | Write every snapshot. Max granularity, ~43K rows/day/interface | |
| Every 10 seconds | Accumulate 5 polls, write averaged sample. ~8.6K rows/day/interface | ✓ |
| Every 30 seconds | Write once per 30s. Minimal I/O but chunky charts | |

**User's choice:** Every 10 seconds

### Per-Interface vs Aggregate Storage

| Option | Description | Selected |
|--------|-------------|----------|
| Per-interface | Store a row per interface per sample. Phase 4/5 can show per-interface history | ✓ |
| Aggregate only | One row per sample with summed total. Simpler but loses per-interface history | |
| Both | Per-interface rows AND pre-computed aggregate row | |

**User's choice:** Per-interface

### Write Method

| Option | Description | Selected |
|--------|-------------|----------|
| Observer pattern | DB layer observes NetworkMonitor snapshots. Clean separation, matches existing StatusBarController pattern | ✓ |
| Direct call from monitor | Monitor calls recorder directly. Simpler flow but couples monitor to persistence | |
| You decide | Let Claude choose | |

**User's choice:** Observer pattern
**Notes:** User requested pros/cons comparison before deciding. After seeing the trade-off analysis (separation of concerns vs simplicity), chose observer pattern to maintain clean architecture.

---

## Aggregation Timing

### Rollup Timing

| Option | Description | Selected |
|--------|-------------|----------|
| Periodic timer | Background task on schedule. Spreads I/O evenly, pre-aggregated data always ready | ✓ |
| On write (inline) | Aggregate on every write at minute boundaries. Real-time but adds write latency | |
| Lazy on query | Aggregate only when charts request data. No background work but slow first load | |

**User's choice:** Periodic timer

### Tier Build Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Cascade | Each tier built from tier below (minutes from raw, hours from minutes, etc.) | ✓ |
| All from raw | Every tier aggregates directly from raw samples | |
| You decide | Let Claude choose | |

**User's choice:** Cascade

---

## Retention & Pruning

### Raw Sample Retention

| Option | Description | Selected |
|--------|-------------|----------|
| 24 hours | Keep raw for 1 day. ~8.6K rows/interface/day | ✓ |
| 7 days | Keep raw for a week. ~60K rows/interface/week | |
| 2 hours | Minimal retention. Only supports last-hour chart | |

**User's choice:** 24 hours

### Aggregated Tier Retention

| Option | Description | Selected |
|--------|-------------|----------|
| Standard retention | Minutes: 7d, Hours: 90d, Days: 1y, Weeks: 2y, Months: forever | |
| Aggressive pruning | Minutes: 2d, Hours: 30d, Days: 6mo, Weeks: 1y, Months: forever | |
| Keep everything | Never prune aggregated tiers. Only raw samples get pruned | ✓ |

**User's choice:** Keep everything

### Pruning Schedule

| Option | Description | Selected |
|--------|-------------|----------|
| On app launch + daily | Prune on launch plus once per 24h while running | ✓ |
| Alongside aggregation timer | Prune as part of periodic aggregation task | |
| You decide | Let Claude choose | |

**User's choice:** On app launch + daily

### Database Size Limit

| Option | Description | Selected |
|--------|-------------|----------|
| No hard limit | Rely on retention policy. DB stays well under 50 MB | ✓ |
| Soft warning at 100 MB | Log warning if exceeded. No automatic action | |
| Hard cap with emergency prune | Aggressive prune if threshold exceeded | |

**User's choice:** No hard limit

---

## Data Granularity

### Raw Sample Fields

| Option | Description | Selected |
|--------|-------------|----------|
| Total bytes transferred | bytesIn and bytesOut per 10s window. Speed derived by dividing by interval | ✓ |
| Average speed | Mean bytesInPerSecond and bytesOutPerSecond. Directly usable but loses total bytes info | |
| Both bytes and speed | Redundant but avoids math at query time | |

**User's choice:** Total bytes transferred

### Aggregated Tier Fields

| Option | Description | Selected |
|--------|-------------|----------|
| Total bytes + peak speed | totalBytesIn/Out (sum) + peakBytesIn/OutPerSec (max). Avg derived from total/duration | ✓ |
| Total bytes only | Just totals. Peak speed data lost at aggregation | |
| Full stats (total + avg + peak + min) | Maximum flexibility but wider rows | |

**User's choice:** Total bytes + peak speed

### Per-Interface in Aggregated Tiers

| Option | Description | Selected |
|--------|-------------|----------|
| Per-interface at all tiers | Keep per-interface rows in all tiers (minute through month) | ✓ |
| Per-interface up to hours | Minute/hour per-interface, day+ aggregate only | |
| Aggregate only in all tiers | All tiers store combined total only | |

**User's choice:** Per-interface at all tiers

---

## Claude's Discretion

- GRDB schema design (table names, columns, indexes)
- Aggregation timer intervals
- DST/timezone boundary handling
- WAL mode and connection pool configuration
- Failed write error handling
- Observer bridging mechanism
- Database migration strategy

## Deferred Ideas

None — discussion stayed within phase scope
