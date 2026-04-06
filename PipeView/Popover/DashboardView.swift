import SwiftUI
import GRDB
import os

/// Combined live speeds + history view for the Dashboard tab (per D-04, D-05, D-06).
///
/// Composes the aggregate header, per-interface list, and history section (time range picker,
/// chart, cumulative stats) in a single scrollable view. Inlines content from MetricsView
/// and HistoryView to avoid nested ScrollViews (per RESEARCH.md Pitfall 3).
///
/// Chart data and cumulative stats are observed reactively via GRDB ValueObservation.
/// When the aggregation engine writes new data to tier tables (~every 2 minutes),
/// the observations fire and the UI updates automatically.
struct DashboardView: View {
    let networkMonitor: NetworkMonitor
    let appDatabase: AppDatabase?

    @Binding var selectedRange: HistoryTimeRange
    @State private var chartData: [ChartDataPoint] = []
    @State private var cumulativeStats: CumulativeStats = CumulativeStats(
        today: (0, 0), week: (0, 0), month: (0, 0)
    )

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
                        today: cumulativeStats.today,
                        week: cumulativeStats.week,
                        month: cumulativeStats.month
                    )
                    .padding(.top, 8)
                }
            }
        }
        // Chart data observation: restarts when selectedRange changes.
        // .task(id:) cancels the previous task and starts a new one,
        // which stops the old ValueObservation and starts a fresh one
        // for the new tier/time range.
        .task(id: selectedRange) {
            await observeChartData()
        }
        // Cumulative stats observation: runs once, auto-updates when
        // hour_samples table changes via aggregation (~every 2 min).
        .task {
            await observeCumulativeStats()
        }
    }

    // MARK: - Reactive Data Observation

    /// Observes chart data for the current selectedRange via GRDB ValueObservation.
    /// Emits new values whenever the underlying aggregation tier table is written to.
    /// Cancelled automatically by SwiftUI when the view disappears or selectedRange changes.
    private func observeChartData() async {
        guard let appDatabase else { return }
        let since = Date.now.addingTimeInterval(-selectedRange.timeInterval)
        let observation = appDatabase.observeChartData(
            tier: selectedRange.tier,
            since: since
        )
        do {
            for try await newData in observation.values(in: appDatabase.dbWriter) {
                chartData = newData
            }
        } catch is CancellationError {
            // Task cancelled (view disappeared or selectedRange changed) -- expected
        } catch {
            Logger.history.error("Chart data observation failed: \(error.localizedDescription)")
            chartData = []
        }
    }

    /// Observes cumulative stats (Today/Week/Month) via GRDB ValueObservation.
    /// Emits new values whenever hour_samples table is written to (~every 2 min).
    /// Cancelled automatically by SwiftUI when the view disappears.
    private func observeCumulativeStats() async {
        guard let appDatabase else { return }
        let observation = appDatabase.observeCumulativeStats()
        do {
            for try await newStats in observation.values(in: appDatabase.dbWriter) {
                cumulativeStats = newStats
            }
        } catch is CancellationError {
            // Task cancelled (view disappeared) -- expected
        } catch {
            Logger.history.error("Cumulative stats observation failed: \(error.localizedDescription)")
            cumulativeStats = CumulativeStats(today: (0, 0), week: (0, 0), month: (0, 0))
        }
    }
}
