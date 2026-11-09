import AppIntents

/// The running Workout's Pause, Resume and Done, as the Live Activity's buttons reach them. Each reads the clock when
/// it runs, because a Live Activity press can't carry its tap time.
protocol WorkoutControls: AnyObject {
    func pause()
    func resume()
    func done()
}

/// Where the Live Activity's buttons find the Workout.
enum LiveActivityControls {
    /// The app sets this at launch, before any button can run. It stays `nil` in the widget extension, where the
    /// buttons never run, so a button that somehow ran there would do nothing rather than crash.
    static var workout: (any WorkoutControls)?
}

/// The Live Activity's Pause button. The system runs it in the app, waking the app if it must, and never in the
/// widget extension. The extension compiles it only so its button can name it.
///
/// A Pause with no Workout running does nothing, so a tap on a Live Activity that outlived its Workout is safe.
struct PauseWorkoutIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Pause Workout"
    /// For the Live Activity only, so it stays out of Shortcuts and Spotlight.
    static let isDiscoverable = false

    @MainActor func perform() async throws -> some IntentResult {
        LiveActivityControls.workout?.pause()
        return .result()
    }
}

/// The Live Activity's Resume button, which runs the same way as its Pause button.
struct ResumeWorkoutIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Resume Workout"
    static let isDiscoverable = false

    @MainActor func perform() async throws -> some IntentResult {
        LiveActivityControls.workout?.resume()
        return .result()
    }
}

/// The Live Activity's Done button, which ends a running open Work, or a running Stopwatch Work past its set length,
/// and runs the same way as its Pause button. The Workout reads the clock when it runs. A Done with no such Work
/// does nothing, so a tap during Rest, while Paused, or a second quick tap is safe.
struct DoneWorkoutIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Done with Work"
    static let isDiscoverable = false

    @MainActor func perform() async throws -> some IntentResult {
        LiveActivityControls.workout?.done()
        return .result()
    }
}
