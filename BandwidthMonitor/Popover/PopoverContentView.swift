import SwiftUI

/// Root view for the popover content, with a segmented tab switcher (per D-04, D-06, D-15, POP-01).
///
/// Takes a `@Binding` for tab selection so that the StatusBarController (Plan 02) can
/// drive tab selection from the right-click context menu (per D-03). The default selection
/// of `.metrics` (per D-06) is set by the StatusBarController when it initializes the shared tab state.
struct PopoverContentView: View {
    let networkMonitor: NetworkMonitor
    let appDatabase: AppDatabase?
    @Binding var selectedTab: PopoverTab

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                ForEach(PopoverTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 16)

            switch selectedTab {
            case .metrics:
                MetricsView(networkMonitor: networkMonitor)
            case .history:
                HistoryView(appDatabase: appDatabase)
            case .preferences:
                PreferencesView()
            }
        }
        .frame(width: 400, height: 550)
    }
}
