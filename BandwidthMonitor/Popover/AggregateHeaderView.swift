import SwiftUI

/// Combined upload/download speed totals displayed at the top of the Metrics tab (per D-10).
///
/// Shows arrow.up + upload speed on the left and arrow.down + download speed on the right,
/// using accent-colored SF Symbols and semibold monospaced-digit values.
struct AggregateHeaderView: View {
    let speed: Speed
    private let formatter = SpeedFormatter()

    var body: some View {
        HStack {
            // Upload total (left)
            HStack(spacing: 4) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.accentColor)
                Text(formatter.format(bytesPerSecond: speed.bytesOutPerSecond))
                    .font(.title2.monospacedDigit())
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Upload speed: \(formatter.format(bytesPerSecond: speed.bytesOutPerSecond))")

            Spacer()

            // Download total (right)
            HStack(spacing: 4) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.accentColor)
                Text(formatter.format(bytesPerSecond: speed.bytesInPerSecond))
                    .font(.title2.monospacedDigit())
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Download speed: \(formatter.format(bytesPerSecond: speed.bytesInPerSecond))")
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }
}
