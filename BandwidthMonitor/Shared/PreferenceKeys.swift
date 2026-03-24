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
        switch self {
        case .auto:         return .auto
        case .both:         return .both
        case .uploadOnly:   return .uploadOnly
        case .downloadOnly: return .downloadOnly
        }
    }
}

// MARK: - Unit Mode Preference

enum UnitModePref: String, CaseIterable, Sendable {
    case auto = "auto"
    case fixedKB = "fixedKB"
    case fixedMB = "fixedMB"
    case fixedGB = "fixedGB"

    func toUnitMode() -> SpeedFormatter.UnitMode {
        switch self {
        case .auto:    return .auto
        case .fixedKB: return .fixedKB
        case .fixedMB: return .fixedMB
        case .fixedGB: return .fixedGB
        }
    }
}

// MARK: - Update Interval Preference

enum UpdateIntervalPref: Int, CaseIterable, Sendable {
    case oneSecond = 1
    case twoSeconds = 2
    case fiveSeconds = 5

    var duration: Duration {
        return .seconds(rawValue)
    }
}
