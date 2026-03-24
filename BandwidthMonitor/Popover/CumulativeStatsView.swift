import SwiftUI

/// Horizontal row of 3 StatCardView cards: Today, This Week, This Month (per D-11, POP-04).
/// Full implementation in Task 2.
struct CumulativeStatsView: View {
    let today: (totalIn: Double, totalOut: Double)
    let week: (totalIn: Double, totalOut: Double)
    let month: (totalIn: Double, totalOut: Double)

    var body: some View {
        HStack(spacing: 8) {
            StatCardView(title: "Today", totalIn: today.totalIn, totalOut: today.totalOut)
            StatCardView(title: "This Week", totalIn: week.totalIn, totalOut: week.totalOut)
            StatCardView(title: "This Month", totalIn: month.totalIn, totalOut: month.totalOut)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
}
