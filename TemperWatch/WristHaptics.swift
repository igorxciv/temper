import Foundation
import HealthKit
import TemperCore
import WatchKit

/// Taps the wrist for each Cue, now or at its date, as `WatchFlow` asks. It plays no sound.
///
/// With the wrist down, a Watch app plays haptics only while its workout session runs, so a haptic plays only while
/// `session` is running.
final class WristHaptics {
    /// The workout session whose running lets the haptics play.
    weak var session: HKWorkoutSession?

    /// Each haptic under way or waiting for its date, with that date.
    private var haptics: [UUID: (date: Date, task: Task<Void, Never>)] = [:]

    func play(_ cue: Cue) {
        start(cue, at: .now)
    }

    func schedule(_ cues: [WatchCue]) {
        for cue in cues {
            start(cue.cue, at: cue.date)
        }
    }

    /// Cancels every haptic due after `date`. One due by then has started, or is about to, and plays out. `date` must
    /// be read in the same main-actor turn as this call, so no haptic can start between the two.
    func cancel(after date: Date) {
        for (id, haptic) in haptics where haptic.date > date {
            haptic.task.cancel()
            haptics[id] = nil
        }
    }

    /// Cancels every haptic, including one partway through its taps.
    func cancelAll() {
        for haptic in haptics.values {
            haptic.task.cancel()
        }
        haptics = [:]
    }

    private func start(_ cue: Cue, at date: Date) {
        let id = UUID()
        let task = Task { [weak self] in
            await self?.play(cue.wristHaptic, at: date)
            self?.haptics[id] = nil
        }
        haptics[id] = (date, task)
    }

    /// The taps are timed on the continuous clock, which keeps counting while the Watch sleeps.
    private func play(_ haptic: WristHaptic, at date: Date) async {
        let clock = ContinuousClock()
        let first = clock.now.advanced(by: .seconds(date.timeIntervalSinceNow))
        for offset in haptic.offsets {
            do {
                try await clock.sleep(until: first.advanced(by: offset), tolerance: .milliseconds(10))
            } catch {
                return
            }
            // A cancel can land after the sleep ends but before this resumes.
            guard !Task.isCancelled, session?.state == .running else { return }
            WKInterfaceDevice.current().play(haptic.tap.type)
        }
    }
}

extension WristHaptic.Tap {
    fileprivate var type: WKHapticType {
        switch self {
        case .notification: .notification
        case .success: .success
        case .click: .click
        }
    }
}
