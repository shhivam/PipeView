import SwiftUI
import Charts

/// Grouped bar chart displaying download/upload data per time bucket (per D-05, D-06, D-08, D-12, POP-02).
/// Full implementation in Task 2.
struct HistoryChartView: View {
    let dataPoints: [ChartDataPoint]
    let timeRange: HistoryTimeRange

    var body: some View {
        Text("Chart placeholder")
            .frame(height: 200)
    }
}
