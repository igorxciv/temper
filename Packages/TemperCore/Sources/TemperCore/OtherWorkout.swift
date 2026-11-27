import Foundation

/// Whether another app's workout, such as Apple Workout, is running on the Watch when the iPhone opens it at Start.
///
/// Apple Watch runs one workout session at a time, across all apps, and the one that starts second ends the other. No
/// API tells an app that another app's session is running. So the Watch leaves it running when it seems to be, and
/// starts no session of its own: the Workout then runs on the iPhone alone, with no Watch screen, heart rate or wrist
/// taps.
///
/// It judges from the pace of heart-rate readings in Health. Under any workout session Apple Watch measures heart rate
/// every few seconds and saves each reading as it goes, while outside one it measures every few minutes. A Watch that
/// misses the other workout starts its session as before, which ends it.
public nonisolated enum OtherWorkout {
    /// How far back the readings are counted.
    public static var window: Duration { .seconds(60) }

    /// How many readings within ``window`` mean a workout is running. Outside one, Apple Watch takes one or two a
    /// minute at most, and under one about a dozen.
    public static var readingsWhileRunning: Int { 5 }

    /// Where the count starts: ``window`` before `now`, or the end of the Watch's own last session if that's later,
    /// so the readings Temper's own session collected don't count.
    public static func countStart(now: Date, ownSessionEnded: Date?) -> Date {
        let windowStart = now.addingTimeInterval(-TimeInterval(window.components.seconds))
        guard let ownSessionEnded else { return windowStart }
        return max(windowStart, ownSessionEnded)
    }

    /// `readings` is the number of heart-rate readings from ``countStart(now:ownSessionEnded:)`` on.
    public static func isRunning(readings: Int) -> Bool {
        readings >= readingsWhileRunning
    }
}
