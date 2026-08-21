import Foundation

enum ISO8601DurationParser {
    /// Parses YouTube's ISO-8601 style durations, e.g. "PT4M13S" -> "4:13", "PT1H2M3S" -> "1:02:03".
    static func parse(_ iso: String) -> String {
        var hours = 0, minutes = 0, seconds = 0
        var numberBuffer = ""
        var isTime = false

        for char in iso {
            switch char {
            case "P":
                continue
            case "T":
                isTime = true
            case "H":
                hours = Int(numberBuffer) ?? 0
                numberBuffer = ""
            case "M":
                if isTime {
                    minutes = Int(numberBuffer) ?? 0
                }
                numberBuffer = ""
            case "S":
                seconds = Int(numberBuffer) ?? 0
                numberBuffer = ""
            default:
                numberBuffer.append(char)
            }
        }

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

enum ViewCountFormatter {
    static func format(_ raw: String?) -> String? {
        guard let raw, let count = Int(raw) else { return nil }
        switch count {
        case 0..<1_000:
            return "\(count) views"
        case 1_000..<1_000_000:
            return String(format: "%.1fK views", Double(count) / 1_000)
        default:
            return String(format: "%.1fM views", Double(count) / 1_000_000)
        }
    }
}
