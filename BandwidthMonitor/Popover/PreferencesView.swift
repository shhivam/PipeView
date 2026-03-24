import ServiceManagement
import SwiftUI
import os

/// Full preferences form for the Preferences tab (per D-13, D-14, D-15, D-16, SYS-02).
///
/// Uses @AppStorage for immediate persistence to UserDefaults. No save button needed --
/// changes take effect within one observation cycle (~2 seconds for menu bar text).
/// Launch-at-login reads from SMAppService.mainApp.status (not UserDefaults) per research guidance.
struct PreferencesView: View {
    // MARK: - @AppStorage Bindings (D-14: UserDefaults-backed)

    @AppStorage(PreferenceKey.displayMode)
    private var displayMode: String = DisplayModePref.auto.rawValue

    @AppStorage(PreferenceKey.unitMode)
    private var unitMode: String = UnitModePref.auto.rawValue

    @AppStorage(PreferenceKey.updateInterval)
    private var updateInterval: Int = UpdateIntervalPref.twoSeconds.rawValue

    // MARK: - Launch at Login (NOT @AppStorage -- reads from SMAppService)

    @State private var launchAtLogin = false

    // MARK: - Computed Bindings

    /// Bridges the raw String @AppStorage to a typed DisplayModePref Binding.
    private var displayModeBinding: Binding<DisplayModePref> {
        Binding(
            get: { DisplayModePref(rawValue: displayMode) ?? .auto },
            set: { displayMode = $0.rawValue }
        )
    }

    /// Bridges the raw String @AppStorage to a typed UnitModePref Binding.
    private var unitModeBinding: Binding<UnitModePref> {
        Binding(
            get: { UnitModePref(rawValue: unitMode) ?? .auto },
            set: { unitMode = $0.rawValue }
        )
    }

    /// Bridges the raw Int @AppStorage to a typed UpdateIntervalPref Binding.
    private var updateIntervalBinding: Binding<UpdateIntervalPref> {
        Binding(
            get: { UpdateIntervalPref(rawValue: updateInterval) ?? .twoSeconds },
            set: { updateInterval = $0.rawValue }
        )
    }

    // MARK: - Body

    var body: some View {
        Form {
            // Display section (D-16)
            Section("Display") {
                Picker("Display Mode", selection: displayModeBinding) {
                    ForEach(DisplayModePref.allCases, id: \.self) { mode in
                        Text(mode.label).tag(mode)
                    }
                }

                Picker("Unit", selection: unitModeBinding) {
                    ForEach(UnitModePref.allCases, id: \.self) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
            }

            // General section (D-16)
            Section("General") {
                Picker("Update Interval", selection: updateIntervalBinding) {
                    ForEach(UpdateIntervalPref.allCases, id: \.self) { interval in
                        Text(interval.label).tag(interval)
                    }
                }

                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        toggleLaunchAtLogin(enabled: newValue)
                    }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    // MARK: - Launch at Login (SMAppService)

    private func toggleLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
                Logger.lifecycle.info("Launch at login enabled by user")
            } else {
                try SMAppService.mainApp.unregister()
                Logger.lifecycle.info("Launch at login disabled by user")
            }
        } catch {
            // Revert toggle on failure
            launchAtLogin = !enabled
            Logger.lifecycle.error("Failed to \(enabled ? "register" : "unregister") login item: \(error.localizedDescription)")
        }
    }
}

// MARK: - Preference Label Extensions

extension DisplayModePref {
    var label: String {
        switch self {
        case .auto:         return "Auto (highest traffic)"
        case .both:         return "Upload + Download"
        case .uploadOnly:   return "Upload Only"
        case .downloadOnly: return "Download Only"
        }
    }
}

extension UnitModePref {
    var label: String {
        switch self {
        case .auto:    return "Auto"
        case .fixedKB: return "KB/s"
        case .fixedMB: return "MB/s"
        case .fixedGB: return "GB/s"
        }
    }
}

extension UpdateIntervalPref {
    var label: String {
        switch self {
        case .oneSecond:   return "1 second"
        case .twoSeconds:  return "2 seconds"
        case .fiveSeconds: return "5 seconds"
        }
    }
}
