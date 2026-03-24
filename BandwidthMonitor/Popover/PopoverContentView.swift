import SwiftUI

/// Root view for the panel content, with a segmented tab switcher (per D-07, D-09, D-10).
///
/// Shows a 2-segment picker (Dashboard | Preferences) at the top. The Dashboard tab
/// shows the combined DashboardView with live speeds and history. Preferences is unchanged.
struct PopoverContentView: View {
    let networkMonitor: NetworkMonitor
    let appDatabase: AppDatabase?
    @Bindable var popoverState: PopoverState

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $popoverState.selectedTab) {
                ForEach(PopoverTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 16)

            switch popoverState.selectedTab {
            case .dashboard:
                DashboardView(
                    networkMonitor: networkMonitor,
                    appDatabase: appDatabase,
                    selectedRange: $popoverState.selectedTimeRange
                )
            case .preferences:
                PreferencesView()
            }
        }
        .frame(width: 480, height: 650)
    }
}
