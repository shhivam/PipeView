import Foundation
import os

extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.bandwidth-monitor"

    /// Monitoring loop lifecycle, poll timing, sysctl reads
    static let monitoring = Logger(subsystem: subsystem, category: "monitoring")

    /// Interface detection, enumeration, name resolution
    static let interfaces = Logger(subsystem: subsystem, category: "interfaces")

    /// Application lifecycle: sleep/wake, launch, terminate
    static let lifecycle = Logger(subsystem: subsystem, category: "lifecycle")

    /// Menu bar status item updates, menu actions
    static let menuBar = Logger(subsystem: subsystem, category: "menuBar")

    /// Database operations: writes, aggregation, pruning, migration
    static let persistence = Logger(subsystem: subsystem, category: "persistence")

    /// Popover UI lifecycle, tab navigation, view events
    static let popover = Logger(subsystem: subsystem, category: "popover")

    /// History tab: chart data loading, cumulative stats queries
    static let history = Logger(subsystem: subsystem, category: "history")
}
