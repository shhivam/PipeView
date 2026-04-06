import Foundation

/// Formats byte values for chart y-axis display.
/// Selects a single unit (KB/MB/GB) for the entire axis and calculates
/// round-number tick values for clean labeling.
struct ChartAxisFormatter: Sendable {
    enum ByteUnit: String, Sendable, Equatable {
        case KB, MB, GB

        var divisor: Double {
            switch self {
            case .KB: return 1_000
            case .MB: return 1_000_000
            case .GB: return 1_000_000_000
            }
        }
    }

    /// Select one unit based on max value -- same unit for all ticks.
    /// Thresholds match ByteFormatter: >= 1B -> GB, >= 1M -> MB, else KB.
    static func selectUnit(forMax maxBytes: Double) -> ByteUnit {
        if maxBytes >= 1_000_000_000 { return .GB }
        if maxBytes >= 1_000_000 { return .MB }
        return .KB
    }

    /// Calculate nice round tick values for the y-axis (in raw bytes).
    /// Returns 5 values: [0, step, 2*step, 3*step, 4*step] where 4*step >= maxBytes.
    static func niceTickValues(maxBytes: Double, unit: ByteUnit) -> [Double] {
        guard maxBytes > 0 else {
            let step = unit.divisor
            return stride(from: 0.0, through: 4 * step, by: step).map { $0 }
        }
        let maxInUnit = maxBytes / unit.divisor
        let niceMax = ceilToNice(maxInUnit)
        let step = niceMax / 4.0
        return stride(from: 0.0, through: niceMax * unit.divisor, by: step * unit.divisor).map { $0 }
    }

    /// Rounds up to a "nice" number: 1, 2, 2.5, 5, 10, 20, 25, 50, 100, ...
    private static func ceilToNice(_ value: Double) -> Double {
        guard value > 0 else { return 1 }
        let exponent = floor(log10(value))
        let fraction = value / pow(10, exponent)
        let niceFraction: Double
        if fraction <= 1.0 { niceFraction = 1.0 }
        else if fraction <= 2.0 { niceFraction = 2.0 }
        else if fraction <= 2.5 { niceFraction = 2.5 }
        else if fraction <= 5.0 { niceFraction = 5.0 }
        else { niceFraction = 10.0 }
        return niceFraction * pow(10, exponent)
    }

    /// Format a raw byte value as a tick label string (number only, no unit suffix).
    /// E.g., formatTick(50_000_000, unit: .MB) -> "50"
    static func formatTick(_ bytes: Double, unit: ByteUnit) -> String {
        let value = bytes / unit.divisor
        if value == 0 { return "0" }
        if value >= 100 { return String(format: "%.0f", value) }
        if value == value.rounded(.toNearestOrEven) && value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }

    /// Compute stable y-axis maximum from data points (CHRT-01).
    /// Returns max(totalBytesIn, totalBytesOut) * 1.1 with a floor of 1024.
    static func yAxisMaxValue(dataPoints: [ChartDataPoint]) -> Double {
        let maxValue = dataPoints.map { max($0.totalBytesIn, $0.totalBytesOut) }.max() ?? 0
        return max(maxValue * 1.1, 1024)
    }
}
