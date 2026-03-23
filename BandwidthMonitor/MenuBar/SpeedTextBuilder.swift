import Foundation

enum DisplayMode: Sendable {
    case auto
    case uploadOnly
    case downloadOnly
    case both
}

struct SpeedTextBuilder: Sendable {
    let formatter: SpeedFormatter

    init(formatter: SpeedFormatter = SpeedFormatter()) {
        self.formatter = formatter
    }

    func build(
        speed: Speed,
        mode: DisplayMode = .auto,
        unit: SpeedFormatter.UnitMode = .auto,
        hasInterfaces: Bool
    ) -> String {
        // D-18: No active interfaces → em dash
        if !hasInterfaces {
            return "\u{2014}"
        }

        switch mode {
        case .auto:
            // D-06: Show direction with higher traffic, upload wins ties
            if speed.bytesOutPerSecond >= speed.bytesInPerSecond {
                return "\u{2191} \(formatter.format(bytesPerSecond: speed.bytesOutPerSecond, unit: unit))"
            } else {
                return "\u{2193} \(formatter.format(bytesPerSecond: speed.bytesInPerSecond, unit: unit))"
            }
        case .uploadOnly:
            // D-07
            return "\u{2191} \(formatter.format(bytesPerSecond: speed.bytesOutPerSecond, unit: unit))"
        case .downloadOnly:
            // D-07
            return "\u{2193} \(formatter.format(bytesPerSecond: speed.bytesInPerSecond, unit: unit))"
        case .both:
            // D-08: Upload then download with space separator
            let up = formatter.format(bytesPerSecond: speed.bytesOutPerSecond, unit: unit)
            let down = formatter.format(bytesPerSecond: speed.bytesInPerSecond, unit: unit)
            return "\u{2191} \(up) \u{2193} \(down)"
        }
    }
}
