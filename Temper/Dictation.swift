import AVFoundation
import Speech
import TemperCore

/// Writes down the owner's description of a Workout as they say it on Describe, with the on-device models keyboard
/// dictation uses, so the words never leave the iPhone.
///
/// Speech is recognized on `Listener`'s queue, and the words come back here, on the main actor, for the screen.
@Observable
final class Dictation {
    enum Status {
        case idle
        /// Asking for the microphone, readying the speech model, or starting capture.
        case starting
        case listening
        case stopping
    }

    private(set) var status = Status.idle
    private var listener: Listener?

    /// Listens until `stop()`, passing the description to `write` each time the words change. Returns whether any
    /// words were heard, and returns `false` at once if Dictation is already listening.
    func listen(replacing earlier: String, write: (String) -> Void) async throws(Failure) -> Bool {
        guard status == .idle else { return false }
        status = .starting
        let listener = Listener()
        self.listener = listener
        defer {
            self.listener = nil
            status = .idle
        }

        guard await Self.mayUseMicrophone() else { throw .microphone }
        guard let locale = await Self.locale() else { throw .language }
        let transcriber = DictationTranscriber(locale: locale, preset: .progressiveShortDictation)
        do {
            if let installation = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                try await installation.downloadAndInstall()
            }
            try await listener.start(transcriber)
        } catch {
            await listener.finish()
            throw .other
        }
        // `stop()` came while starting, before there were results to end.
        guard status == .starting else {
            await listener.finish()
            return false
        }

        status = .listening
        var description = DictatedDescription(replacing: earlier)
        do {
            // The results end when `stop()` finishes the listener.
            for try await result in transcriber.results {
                description.hear(String(result.text.characters), isSettled: result.isFinal)
                write(description.text)
            }
        } catch {
            await listener.finish()
            throw .other
        }
        await listener.finish()
        return description.hasHeardWords
    }

    /// Stops listening, once the words said so far are settled.
    func stop() {
        guard status == .starting || status == .listening, let listener else { return }
        status = .stopping
        Task {
            await listener.finish()
        }
    }

    private static func mayUseMicrophone() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: true
        case .notDetermined: await AVCaptureDevice.requestAccess(for: .audio)
        default: false
        }
    }

    /// The iPhone's language, or English, the language of Temper's screens, if Dictation can't hear the iPhone's.
    private static func locale() async -> Locale? {
        if let current = await DictationTranscriber.supportedLocale(equivalentTo: .current) {
            return current
        }
        return await DictationTranscriber.supportedLocale(equivalentTo: Locale(identifier: "en-US"))
    }

    /// What went wrong dictating, in words for the screen.
    enum Failure: Error {
        case microphone
        case language
        case other

        var explanation: String {
            switch self {
            case .microphone: "Allow Temper to use the microphone in Settings to dictate a Workout."
            case .language: "Dictation can't hear this iPhone's language yet. Type the Workout instead."
            case .other: "Dictation stopped. Try again, or type the Workout."
            }
        }
    }
}

/// Owns the capture session and the analyzer. It runs on a queue of its own because starting and stopping capture
/// block until they're done.
private actor Listener {
    private static let queue = DispatchSerialQueue(label: "Temper.dictation", qos: .userInitiated)

    /// Words Describe expects, so the recognizer prefers "Rest" to "rust" and "sets" to "sex".
    private static let vocabulary = [
        "Work", "Rest", "Round", "Rounds", "sets", "reps", "Prepare", "Cooldown", "Open", "Done", "Intervals",
        "Stopwatch", "Tabata", "EMOM", "AMRAP",
    ]

    nonisolated var unownedExecutor: UnownedSerialExecutor {
        Self.queue.asUnownedSerialExecutor()
    }

    private var provider: CaptureInputSequenceProvider?
    private var analyzer: SpeechAnalyzer?
    private var isFinished = false

    /// Starts the microphone, unless `finish()` has already come. The analyzer then reads it on its own until
    /// `finish()`.
    func start(_ transcriber: DictationTranscriber) async throws {
        guard !isFinished else { return }
        guard let microphone = AVCaptureDevice.default(for: .audio) else { throw NoMicrophone() }
        // This also sets up the app's audio session for recording.
        let provider = try await CaptureInputSequenceProvider.providerWithSession(
            from: microphone, compatibleWith: [transcriber])
        // `finish()` can come during the wait, after the audio session is set up.
        guard !isFinished else {
            Self.releaseAudioSession()
            return
        }
        let context = AnalysisContext()
        context.contextualStrings[.general] = Self.vocabulary
        analyzer = SpeechAnalyzer(
            inputSequence: provider.analyzerInputs, modules: [transcriber], analysisContext: context)
        self.provider = provider
        provider.captureSession.startRunning()
    }

    /// Stops the microphone, settles the words heard so far, and ends the results. It hands the audio session back
    /// so other apps' audio can resume, before a Workout's Cues take it.
    func finish() async {
        guard !isFinished else { return }
        isFinished = true
        provider?.captureSession.stopRunning()
        if let analyzer {
            try? await analyzer.finalize(through: nil)
            await analyzer.cancelAndFinishNow()
        }
        if provider != nil {
            Self.releaseAudioSession()
        }
        provider = nil
        analyzer = nil
    }

    /// Notifying on deactivation is what lets other apps' audio resume.
    private static func releaseAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    nonisolated struct NoMicrophone: Error {}
}
