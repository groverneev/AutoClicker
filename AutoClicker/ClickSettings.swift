import Foundation

/// Everything the user can configure in the main window. Persisted as JSON in UserDefaults.
struct ClickSettings: Codable, Equatable {
    enum IntervalMode: String, Codable {
        case fixed
        case random
    }

    enum RepeatMode: String, Codable {
        case count
        case untilStopped
    }

    var intervalMode: IntervalMode = .fixed
    var hours = 0
    var minutes = 0
    var seconds = 0
    var milliseconds = 100

    var randomMin = 100
    var randomMax = 200

    var button: MouseButton = .left

    var repeatMode: RepeatMode = .untilStopped
    var repeatCount = 10

    /// Fixed interval in milliseconds, never less than 1 ms.
    var fixedIntervalMilliseconds: Int {
        let total = max(0, hours) * 3_600_000
            + max(0, minutes) * 60_000
            + max(0, seconds) * 1_000
            + max(0, milliseconds)
        return max(1, total)
    }

    /// Random range in milliseconds, with min/max swapped if they were entered backwards.
    var randomRangeMilliseconds: ClosedRange<Int> {
        let a = max(1, randomMin)
        let b = max(1, randomMax)
        return min(a, b)...max(a, b)
    }

    var job: ClickJob {
        let interval: ClickJob.Interval = switch intervalMode {
        case .fixed:
            .fixed(milliseconds: fixedIntervalMilliseconds)
        case .random:
            .random(milliseconds: randomRangeMilliseconds)
        }
        let limit: Int? = repeatMode == .count ? max(1, repeatCount) : nil
        return ClickJob(interval: interval, button: button, limit: limit)
    }
}

extension ClickSettings {
    private static let defaultsKey = "clickSettings"

    static func load() -> ClickSettings {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let settings = try? JSONDecoder().decode(ClickSettings.self, from: data)
        else { return ClickSettings() }
        return settings
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }
}
