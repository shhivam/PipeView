import SwiftUI
import Charts

/// Grouped bar chart displaying download/upload data per time bucket (per D-05, D-06, D-08, D-12, POP-02).
///
/// Renders two `BarMark` per `ChartDataPoint` (download + upload), grouped by direction.
/// Supports interactive selection with a tooltip showing formatted byte values.
/// Y-axis is locked to a pre-computed max (CHRT-01), x-axis labels vary per time range (CHRT-02, CHRT-03),
/// and y-axis labels show auto-scaled KB/MB/GB (CHRT-04).
struct HistoryChartView: View {
    let dataPoints: [ChartDataPoint]
    let timeRange: HistoryTimeRange

    @State private var selectedTimestamp: Date?

    private let formatter = ByteFormatter()

    // CHRT-01: Pre-computed y-axis max for stable domain (10% headroom)
    private var yAxisMax: Double {
        ChartAxisFormatter.yAxisMaxValue(dataPoints: dataPoints)
    }

    // CHRT-04: Single unit for all y-axis labels
    private var yAxisUnit: ChartAxisFormatter.ByteUnit {
        let maxValue = dataPoints.map { max($0.totalBytesIn, $0.totalBytesOut) }.max() ?? 0
        return ChartAxisFormatter.selectUnit(forMax: maxValue)
    }

    // CHRT-04: Pre-computed nice tick values in raw bytes
    private var yAxisTicks: [Double] {
        ChartAxisFormatter.niceTickValues(maxBytes: yAxisMax, unit: yAxisUnit)
    }

    // X-axis domain: always span the full selected time range regardless of data sparsity
    private var xDomainStart: Date {
        Date.now.addingTimeInterval(-timeRange.timeInterval)
    }

    // CHRT-02: "3/18" format for 7D view (short numeric date, NOT day-of-week)
    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M/d"
        return f
    }()

    // CHRT-03: "Mar 1" format for 30D view (every 5th day)
    private static let mediumDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    var body: some View {
        ZStack {
            Group {
                switch timeRange {
                case .oneHour:
                    chartBase.chartXAxis {
                        AxisMarks(values: .stride(by: .minute, count: 15)) { _ in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel(format: .dateTime.hour().minute())
                        }
                    }
                case .twentyFourHours:
                    chartBase.chartXAxis {
                        AxisMarks(values: .stride(by: .hour, count: 6)) { _ in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .abbreviated)))
                        }
                    }
                case .sevenDays:
                    chartBase.chartXAxis {
                        AxisMarks(values: .stride(by: .day)) { value in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel {
                                if let date = value.as(Date.self) {
                                    Text(Self.shortDateFormatter.string(from: date))
                                }
                            }
                        }
                    }
                case .thirtyDays:
                    chartBase.chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: 5)) { value in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel {
                                if let date = value.as(Date.self) {
                                    Text(Self.mediumDateFormatter.string(from: date))
                                }
                            }
                        }
                    }
                }
            }
            .frame(height: 200)
            // Prevent y-axis labels (especially the topmost) from overflowing
            // above the chart frame and overlapping with the interface breakdown section.
            .clipped()

            // Empty state overlay (per D-12)
            if dataPoints.isEmpty {
                Text("No data yet")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
        }
        // Reserve space above the chart so the topmost y-axis label has room
        // to render within the clipped bounds without being cut off.
        .padding(.top, 4)
    }

    // MARK: - Chart

    private var chartBase: some View {
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
        // Lock x-axis to the full selected time range so sparse data doesn't compress the axis
        .chartXScale(domain: xDomainStart...Date.now)
        // CHRT-01: Lock y-axis to prevent reflow on hover/selection
        .chartYScale(domain: 0...yAxisMax)
        // CHRT-04: Human-readable y-axis labels with auto-scaled unit
        .chartYAxis {
            AxisMarks(values: yAxisTicks) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let bytes = value.as(Double.self) {
                        Text("\(ChartAxisFormatter.formatTick(bytes, unit: yAxisUnit)) \(yAxisUnit.rawValue)")
                    }
                }
            }
        }
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
