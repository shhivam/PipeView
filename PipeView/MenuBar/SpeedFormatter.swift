import Foundation

struct SpeedFormatter: Sendable {
    enum UnitMode: Sendable {
        case auto
        case fixedKB
        case fixedMB
        case fixedGB
    }

    func format(bytesPerSecond: Double, unit: UnitMode = .auto) -> String {
        // D-10: Below 1 KB/s threshold
        if bytesPerSecond < 1_000 {
            return "0 KB/s"
        }

        let (value, suffix) = selectUnit(bytesPerSecond: bytesPerSecond, mode: unit)
        return "\(formatValue(value)) \(suffix)"
    }

    // D-09 + D-11: Unit selection with ceiling behavior
    private func selectUnit(bytesPerSecond: Double, mode: UnitMode) -> (Double, String) {
        switch mode {
        case .auto, .fixedGB:
            if bytesPerSecond >= 1_000_000_000 {
                return (bytesPerSecond / 1_000_000_000, "GB/s")
            } else if bytesPerSecond >= 1_000_000 {
                return (bytesPerSecond / 1_000_000, "MB/s")
            } else {
                return (bytesPerSecond / 1_000, "KB/s")
            }
        case .fixedMB:
            // Ceiling at MB/s — cannot promote to GB
            if bytesPerSecond >= 1_000_000 {
                return (bytesPerSecond / 1_000_000, "MB/s")
            } else {
                return (bytesPerSecond / 1_000, "KB/s")
            }
        case .fixedKB:
            // Always KB/s
            return (bytesPerSecond / 1_000, "KB/s")
        }
    }

    // D-02: Adaptive precision
    private func formatValue(_ value: Double) -> String {
        if value >= 100 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }
}
