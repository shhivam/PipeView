import SwiftUI

/// A single row in the per-interface breakdown list (per D-07, D-08, D-09).
///
/// Shows the interface's SF Symbol icon and display name on the left,
/// with upload and download speeds on the right using Unicode arrows.
struct InterfaceRowView: View {
    let interfaceSpeed: InterfaceSpeed
    private let formatter = SpeedFormatter()

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: sfSymbolName(for: interfaceSpeed.interface))
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .frame(width: 20)

            Text(interfaceSpeed.interface.displayName)
                .font(.body)
                .foregroundStyle(.primary)

            Spacer()

            HStack(spacing: 12) {
                Text("\u{2191} \(formatter.format(bytesPerSecond: interfaceSpeed.speed.bytesOutPerSecond))")
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.primary)

                Text("\u{2193} \(formatter.format(bytesPerSecond: interfaceSpeed.speed.bytesInPerSecond))")
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.primary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(interfaceSpeed.interface.displayName): upload \(formatter.format(bytesPerSecond: interfaceSpeed.speed.bytesOutPerSecond)), download \(formatter.format(bytesPerSecond: interfaceSpeed.speed.bytesInPerSecond))")
    }
}
