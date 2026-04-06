import SwiftUI

/// Individual stat card showing combined total with per-direction breakdown (per D-09, D-10, D-11, POP-04).
///
/// Displays a title label, a primary combined byte total, and a secondary HStack
/// with download/upload arrows and formatted values.
struct StatCardView: View {
    let title: String
    let totalIn: Double
    let totalOut: Double

    var totalBytes: Double { totalIn + totalOut }

    private let formatter = ByteFormatter()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Label: "Today", "This Week", "This Month"
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            // Primary combined number (per D-09)
            Text(formatter.format(bytes: totalBytes))
                .font(.title3)
                .fontWeight(.semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            // Per-direction breakdown
            HStack(spacing: 8) {
                Text("\u{2193} \(formatter.format(bytes: totalIn))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text("\u{2191} \(formatter.format(bytes: totalOut))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }
}
