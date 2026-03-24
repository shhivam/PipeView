import Foundation

// MARK: - Preference Key Constants

/// String constants for UserDefaults preference keys.
/// Launch-at-login is NOT stored in UserDefaults (read from SMAppService per research guidance).
enum PreferenceKey {
    static let displayMode = "displayMode"
    static let unitMode = "unitMode"
    static let updateInterval = "updateInterval"
}

// MARK: - Display Mode Preference

enum DisplayModePref: String, CaseIterable, Sendable {
    case auto = "auto"
    case both = "both"
    case uploadOnly = "uploadOnly"
    case downloadOnly = "downloadOnly"

    func toDisplayMode() -> DisplayMode {
        // Stub: returns wrong value to fail tests
        return .auto
    }
}

// MARK: - Unit Mode Preference

enum UnitModePref: String, CaseIterable, Sendable {
    case auto = "auto"
    case fixedKB = "fixedKB"
    case fixedMB = "fixedMB"
    case fixedGB = "fixedGB"

    func toUnitMode() -> SpeedFormatter.UnitMode {
        // Stub: returns wrong value to fail tests
        return .auto
    }
}

// MARK: - Update Interval Preference

enum UpdateIntervalPref: Int, CaseIterable, Sendable {
    case oneSecond = 1
    case twoSeconds = 2
    case fiveSeconds = 5

    var duration: Duration {
        // Stub: returns wrong value to fail tests
        return .seconds(0)
    }
}
