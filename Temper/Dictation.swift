import AVFoundation
import Observation
import Speech
import TemperCore

/// Listens through the microphone while the owner says a Workout on Describe, and writes down what they say.
///
/// Speech is recognized on the iPhone by `SpeechAnalyzer`, so nothing said leaves it, and words show as they're
/// heard. Temper is English only, as its instructions to the language model are, so it listens for English.
@Observable
final class Dictation {
    enum State: Equatable {
        case idle
        /// Asking for the microphone, or fetching the speech model the first time.
        case preparing
        case listening
        /// Writing down the last words after Stop.
        case finishing
    }

    private(set) var state = State.idle
    /// What was heard since listening last started.
    private(set) var transcript = Transcript()
    /// Why listening couldn't start or stopped early, in words for the screen.
    private(set) var problem: String?

    @ObservationIgnored private var listener: Listener?
    @ObservationIgnored private var task: Task<Void, Never>?
    /// Counts each start and each stop while preparing, so a start that was stopped before it got going knows to
    /// leave the state alone.
    @ObservationIgnored private var attempt = 0

    /// Starts listening, with a fresh transcript. It does nothing unless idle.
    func start() {
        guard state == .idle else { return }
        attempt += 1
        let current = attempt
        state = .preparing
        problem = nil
        transcript = Transcript()
        task = Task {
            do throws(Failure) {
                guard await Self.isMicrophoneAllowed() else { throw .microphoneDenied }
                let listener = try await Listener.make()
                guard attempt == current else { return }
                try await listener.start()
                guard attempt == current else {
                    await listener.stop()
                    return
                }
                self.listener = listener
                state = .listening
                do {
                    for try await piece in listener.pieces {
                        transcript.hear(piece.text, isFinal: piece.isFinal)
                    }
                } catch {
                    // Stop ends the pieces too, which isn't a problem.
                    if state == .listening {
                        throw .stopped
                    }
                }
                if state == .listening {
                    await listener.stop()
                }
            } catch {
                if attempt == current {
                    problem = error.explanation
                }
            }
            if attempt == current {
                listener = nil
                state = .idle
            }
        }
    }

    /// Stops listening. Words already heard are still written down before it goes idle.
    func stop() {
        switch state {
        case .idle, .finishing:
            return
        case .preparing:
            // Fetching the speech model can take a while, so going idle doesn't wait for it.
            attempt += 1
            task?.cancel()
            state = .idle
        case .listening:
            state = .finishing
            if let listener {
                Task { await listener.stop() }
            }
        }
    }

    private static func isMicrophoneAllowed() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: true
        case .notDetermined: await AVCaptureDevice.requestAccess(for: .audio)
        default: false
        }
    }

    /// Why listening couldn't go on, in words for the screen.
    nonisolated enum Failure: Error {
        case microphoneDenied
        case noMicrophone
        case language
        case model
        case stopped

        var explanation: String {
            switch self {
            case .microphoneDenied: "Temper can't use the microphone. Allow it in Settings, or type instead."
            case .noMicrophone: "No microphone is available. Type instead."
            case .language: "Dictation isn't available in English on this iPhone. Type instead."
            case .model: "The speech model couldn't be downloaded. Try again later, or type instead."
            case .stopped: "Dictation stopped. Check the words, or try again."
            }
        }
    }
}

/// One piece of speech as the recognizer reported it. `isFinal` says it won't be revised.
private nonisolated struct HeardPiece: Sendable {
    let text: String
    let isFinal: Bool
}

/// The microphone's capture session and the analyzer reading it, for one stretch of listening.
///
/// Starting and stopping a capture session blocks for a while, so it runs on its own queue, off the main thread and
/// the shared thread pool.
private actor Listener {
    private static let queue = DispatchSerialQueue(label: "Temper.dictation", qos: .userInitiated)

    nonisolated var unownedExecutor: UnownedSerialExecutor {
        Self.queue.asUnownedSerialExecutor()
    }

    nonisolated let pieces: any AsyncSequence<HeardPiece, any Error> & Sendable
    private let analyzer: SpeechAnalyzer
    private let capture: CaptureInputSequenceProvider

    private init(
        pieces: any AsyncSequence<HeardPiece, any Error> & Sendable,
        analyzer: SpeechAnalyzer,
        capture: CaptureInputSequenceProvider
    ) {
        self.pieces = pieces
        self.analyzer = analyzer
        self.capture = capture
    }

    /// Picks a transcriber for English, fetches its model if the iPhone doesn't have it yet, and sets up the
    /// microphone.
    @concurrent static func make() async throws(Dictation.Failure) -> Listener {
        guard let microphone = AVCaptureDevice.default(for: .audio) else { throw .noMicrophone }
        let module: any SpeechModule
        let pieces: any AsyncSequence<HeardPiece, any Error> & Sendable
        // SpeechTranscriber is newer and better at long speech. Older iPhones get the system dictation model.
        if SpeechTranscriber.isAvailable, let locale = await SpeechTranscriber.supportedLocale(equivalentTo: english) {
            let transcriber = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
            module = transcriber
            pieces = transcriber.results.map { @Sendable in
                HeardPiece(text: String($0.text.characters), isFinal: $0.isFinal)
            }
        } else if let locale = await DictationTranscriber.supportedLocale(equivalentTo: english) {
            let transcriber = DictationTranscriber(locale: locale, preset: .progressiveLongDictation)
            module = transcriber
            pieces = transcriber.results.map { @Sendable in
                HeardPiece(text: String($0.text.characters), isFinal: $0.isFinal)
            }
        } else {
            throw .language
        }

        do {
            if let request = try await AssetInventory.assetInstallationRequest(supporting: [module]) {
                try await request.downloadAndInstall()
            }
        } catch {
            throw .model
        }

        do {
            let capture = try await CaptureInputSequenceProvider.providerWithSession(
                from: microphone, compatibleWith: [module])
            let context = AnalysisContext()
            // Temper's own words, so "Rest" isn't heard as "rust" and "Rounds" as "rams".
            context.contextualStrings[.general] = ["Work", "Rest", "Round", "Rounds", "Prepare", "Cooldown", "Done"]
            let analyzer = SpeechAnalyzer(modules: [module])
            try await analyzer.setContext(context)
            return Listener(pieces: pieces, analyzer: analyzer, capture: capture)
        } catch {
            throw .noMicrophone
        }
    }

    func start() async throws(Dictation.Failure) {
        do {
            try await analyzer.start(inputSequence: capture.analyzerInputs)
        } catch {
            throw .noMicrophone
        }
        capture.captureSession.startRunning()
    }

    /// Stops the microphone, writes down what it already heard, and ends the pieces. Then it gives up the audio
    /// session, so music the capture session lowered comes back up.
    func stop() async {
        capture.captureSession.stopRunning()
        try? await analyzer.finalize(through: nil)
        await analyzer.cancelAndFinishNow()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// English as the owner's region speaks it, or US English when the iPhone is set to another language.
    private nonisolated static var english: Locale {
        Locale.current.language.languageCode == .english ? Locale.current : Locale(identifier: "en-US")
    }
}
