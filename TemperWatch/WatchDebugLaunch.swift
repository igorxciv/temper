#if DEBUG
    import Foundation
    import TemperCore

    /// `xcrun simctl spawn <watch> defaults write org.example.temper.watchkitapp debugRunning -bool YES` opens the
    /// running screen on a sample Work with a sample heart rate, for the App Store screenshot. The Simulator can't stage
    /// a real one: a Watch Simulator neither shares the iPhone's Health grant nor mirrors its workout session to the
    /// iPhone. A launch argument doesn't reach a Watch app, so it's a default; `defaults delete` turns it off.
    enum WatchDebugLaunch {
        static var isRunning: Bool { UserDefaults.standard.bool(forKey: "debugRunning") }

        /// The first Work of the Plan the iPhone screenshots run, at a heart rate in Zone 4. It ends at
        /// `debugRunningEnd`, in seconds since 1970, so it can end with the iPhone's, or 28 seconds after launch.
        static func phase(at now: Date = .now) -> WatchPhase {
            let stored = UserDefaults.standard.double(forKey: "debugRunningEnd")
            let end = stored > 0 ? Date(timeIntervalSince1970: stored) : now.addingTimeInterval(28)
            return WatchPhase(
                kind: .work, round: 1, start: end.addingTimeInterval(-40), end: end,
                pausedAt: nil, countsUp: false, line: .value("1", caption: .after("of 4"), spoken: "Round 1 of 4"),
                capsule: .pause, title: "Burpees")
        }

        static let heartRate = LiveHeartRate.preview(bpm: 158)
    }
#endif
