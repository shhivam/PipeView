import SwiftUI
import Charts

/// Grouped bar chart displaying download/upload data per time bucket (per D-05, D-06, D-08, D-12, POP-02).
///
/// Renders two `BarMark` per `ChartDataPoint` (download + upload), grouped by direction.
/// Supports interactive selection with a tooltip showing formatted byte values.
struct HistoryChartView: View {
    let dataPoints: [ChartDataPoint]
    let timeRange: HistoryTimeRange

    @State private var selectedTimestamp: Date?

    private let formatter = ByteFormatter()

    var body: some View {
        ZStack {
            chart
                .frame(height: 200)

            // Empty state overlay (per D-12)
            if dataPoints.isEmpty {
                Text("No data yet")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
        }
    }

    // MARK: - Chart

    private var chart: some View {
        Chart {
            ForEach(dataPoints) { point in
                // Download bar
                BarMark(
                    x: .value("Time", point.timestamp, unit: timeRange.calendarUnit),
                    y: .value("Bytes", point.totalBytesIn)
                )
                .foregroundStyle(by: .value("Direction", "Download"))
                .position(by: .value("Direction", "Download"))

                // Upload bar
                BarMark(
                    x: .value("Time", point.timestamp, unit: timeRange.calendarUnit),
                    y: .value("Bytes", point.totalBytesOut)
                )
                .foregroundStyle(by: .value("Direction", "Upload"))
                .position(by: .value("Direction", "Upload"))
            }

            // Selection rule mark with tooltip (per D-08)
            if let selectedTimestamp, let closest = closestPoint(to: selectedTimestamp) {
                RuleMark(x: .value("Selected", closest.timestamp, unit: timeRange.calendarUnit))
                    .foregroundStyle(.secondary.opacity(0.3))
                    .annotation(position: .top, alignment: .center) {
                        tooltipView(for: closest)
                    }
            }
        }
        .chartForegroundStyleScale([
            "Download": Color.accentColor,
            "Upload": Color.secondary.opacity(0.7)
        ])
        .chartXSelection(value: $selectedTimestamp)
    }

    // MARK: - Tooltip

    private func tooltipView(for point: ChartDataPoint) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(formatTimestamp(point.timestamp))
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 6, height: 6)
                Text("\u{2193} \(formatter.format(bytes: point.totalBytesIn))")
                    .font(.caption2)
            }
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.secondary.opacity(0.7))
                    .frame(width: 6, height: 6)
                Text("\u{2191} \(formatter.format(bytes: point.totalBytesOut))")
                    .font(.caption2)
            }
        }
        .padding(6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Helpers

    /// Finds the closest ChartDataPoint to the given timestamp.
    private func closestPoint(to date: Date) -> ChartDataPoint? {
        dataPoints.min(by: {
            abs($0.timestamp.timeIntervalSince(date)) < abs($1.timestamp.timeIntervalSince(date))
        })
    }

    /// Formats timestamp appropriately for the current time range.
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        switch timeRange {
        case .oneHour:
            formatter.dateFormat = "h:mm a"
        case .twentyFourHours:
            formatter.dateFormat = "h a"
        case .sevenDays, .thirtyDays:
            formatter.dateFormat = "MMM d"
        }
        return formatter.string(from: date)
    }
}
