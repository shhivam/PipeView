import SwiftUI

/// The Metrics tab content, composing the aggregate header and per-interface list (per D-10, D-11).
///
/// Reads `networkMonitor.aggregateSpeed` and `networkMonitor.interfaceSpeeds` directly.
/// Because `NetworkMonitor` is `@Observable`, SwiftUI automatically tracks these property
/// accesses and re-renders when values change -- no `@ObservedObject` or `@StateObject` needed.
struct MetricsView: View {
    let networkMonitor: NetworkMonitor

    var body: some View {
        VStack(spacing: 0) {
            AggregateHeaderView(speed: networkMonitor.aggregateSpeed)

            Divider()

            if networkMonitor.interfaceSpeeds.isEmpty {
                Spacer()
                Text("No active network interfaces detected.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(networkMonitor.interfaceSpeeds) { interfaceSpeed in
                            InterfaceRowView(interfaceSpeed: interfaceSpeed)
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
    }
}
