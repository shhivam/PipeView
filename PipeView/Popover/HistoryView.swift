import SwiftUI
import os

/// Container view for the History tab: time range picker + chart + cumulative stats (per D-03, D-04).
///
/// Loads chart data from AppDatabase based on the selected time range, and fetches
/// cumulative stats for Today, This Week, and This Month periods.
struct HistoryView: View {
    let appDatabase: AppDatabase?

    @State private var selectedRange: HistoryTimeRange = .twentyFourHours
    @State private var chartData: [ChartDataPoint] = []
    @State private var todayStats: (totalIn: Double, totalOut: Double) = (0, 0)
    @State private var weekStats: (totalIn: Double, totalOut: Double) = (0, 0)
    @State private var monthStats: (totalIn: Double, totalOut: Double) = (0, 0)

    var body: some View {
        if appDatabase == nil {
            emptyStateView
        } else {
            contentView
        }
    }

    // MARK: - Content

    private var contentView: some View {
        VStack(spacing: 0) {
            // Time range segmented control (per D-04)
            Picker("Time Range", selection: $selectedRange) {
                ForEach(HistoryTimeRange.allCases, id: \.self) { range in
                    Text(range.displayLabel).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 8)

            // Chart (hero element per D-03)
            HistoryChartView(dataPoints: chartData, timeRange: selectedRange)
                .padding(.horizontal, 16)
                .padding(.top, 12)

            Spacer()

            // Cumulative stats cards (per D-11)
            CumulativeStatsView(
                today: todayStats,
                week: weekStats,
                month: monthStats
            )
        }
        .onChange(of: selectedRange) {
            loadChartData()
        }
        .onAppear {
            loadChartData()
            loadStats()
        }
    }

    private var emptyStateView: some View {
        VStack {
            Spacer()
            Text("No data yet")
                .foregroundStyle(.secondary)
                .font(.callout)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
