import Foundation

/// Formats total byte counts (not speeds) into human-readable strings.
/// Follows the same adaptive precision as SpeedFormatter per D-10.
struct ByteFormatter: Sendable {
    func format(bytes: Double) -> String {
        // Below 1 KB threshold
        if bytes < 1_000 {
            return "0 KB"
        }

        let (value, suffix) = selectUnit(bytes: bytes)
        return "\(formatValue(value)) \(suffix)"
    }

    // MARK: - Private

    private func selectUnit(bytes: Double) -> (Double, String) {
        if bytes >= 1_000_000_000 {
            return (bytes / 1_000_000_000, "GB")
        } else if bytes >= 1_000_000 {
            return (bytes / 1_000_000, "MB")
        } else {
            return (bytes / 1_000, "KB")
        }
    }

    /// Adaptive precision: >= 100 no decimal, else 1 decimal place.
    private func formatValue(_ value: Double) -> String {
        if value >= 100 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }
}
