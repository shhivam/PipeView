import SwiftUI

/// Individual stat card showing combined total and per-direction breakdown (per D-09, D-10, D-11, POP-04).
/// Full implementation in Task 2.
struct StatCardView: View {
    let title: String
    let totalIn: Double
    let totalOut: Double

    var body: some View {
        Text(title)
    }
}
