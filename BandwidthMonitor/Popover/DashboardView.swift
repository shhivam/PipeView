import SwiftUI
import os

/// Combined live speeds + history view for the Dashboard tab (per D-04, D-05, D-06).
///
/// Composes the aggregate header, per-interface list, and history section (time range picker,
/// chart, cumulative stats) in a single scrollable view. Inlines content from MetricsView
/// and HistoryView to avoid nested ScrollViews (per RESEARCH.md Pitfall 3).
struct DashboardView: View {
    let networkMonitor: NetworkMonitor
    let appDatabase: AppDatabase?

    @State private var selectedRange: HistoryTimeRange = .twentyFourHours
    @State private var chartData: [ChartDataPoint] = []
    @State private var todayStats: (totalIn: Double, totalOut: Double) = (0, 0)
    @State private var weekStats: (totalIn: Double, totalOut: Double) = (0, 0)
    @State private var monthStats: (totalIn: Double, totalOut: Double) = (0, 0)

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // MARK: - Live Speeds Section

                AggregateHeaderView(speed: networkMonitor.aggregateSpeed)

                Divider()

                if networkMonitor.interfaceSpeeds.isEmpty {
                    Text("No active network interfaces detected.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 16)
                } else {
                    LazyVStack(spacing: 4) {
                        ForEach(networkMonitor.interfaceSpeeds) { interfaceSpeed in
                            InterfaceRowView(interfaceSpeed: interfaceSpeed)
                        }
                    }
                    .padding(.top, 8)
                }

                // MARK: - Section Divider (D-05)

                Divider()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                // MARK: - History Section

                if appDatabase == nil {
                    Text("No data yet")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                        .padding(.vertical, 16)
                } else {
                    // Time range picker
                    Picker("Time Range", selection: $selectedRange) {
                        ForEach(HistoryTimeRange.allCases, id: \.self) { range in
                            Text(range.displayLabel).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    // Chart
                    HistoryChartView(dataPoints: chartData, timeRange: selectedRange)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                    // Cumulative stats
                    CumulativeStatsView(
                        today: todayStats,
                        week: weekStats,
                        month: monthStats
                    )
                    .padding(.top, 8)
                }
            }
        }
        .task {
            loadChartData()
            loadStats()
        }
        .onChange(of: selectedRange) {
            loadChartData()
        }
    }

    // MARK: - Data Loading

    private func loadChartData() {
        guard let appDatabase else { return }
        let since = Date.now.addingTimeInterval(-selectedRange.timeInterval)
        do {
            chartData = try appDatabase.fetchChartData(
                tier: selectedRange.tier,
                since: since
            )
            Logger.history.debug("Loaded \(chartData.count) chart data points for \(selectedRange.rawValue)")
        } catch {
            Logger.history.error("Failed to load chart data: \(error.localizedDescription)")
            chartData = []
        }
    }

    private func loadStats() {
        guard let appDatabase else { return }
        let calendar = Calendar.current
        let now = Date.now

        // Today: start of current day in local timezone (per Pitfall 6)
        let todayStart = calendar.startOfDay(for: now)

        // This Week: start of current week in local timezone
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? todayStart

        // This Month: start of current month in local timezone
        let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? todayStart

        do {
            todayStats = try appDatabase.fetchCumulativeStats(since: todayStart)
            weekStats = try appDatabase.fetchCumulativeStats(since: weekStart)
            monthStats = try appDatabase.fetchCumulativeStats(since: monthStart)
            Logger.history.debug("Loaded cumulative stats: today, week, month")
        } catch {
            Logger.history.error("Failed to load cumulative stats: \(error.localizedDescription)")
            todayStats = (0, 0)
            weekStats = (0, 0)
            monthStats = (0, 0)
        }
    }
}
