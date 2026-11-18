import AVFAudio
import TemperCore

/// The Cues, rendered once and kept in memory only. It outlives any one Workout.
///
/// The plain Cues are rendered at launch. A Cue that says an Exercise is rendered when a Workout that needs it
/// starts, and kept for the next one. A new Round Sound renders again every Cue made with it, and nothing else.
///
/// A class with a lock, because the audio adapter has to read it without suspending. Buffers are never written
/// to after rendering.
nonisolated final class CueBank: @unchecked Sendable {
    /// A Cue as it sounds: plain, or saying an Exercise.
    struct Sound: Hashable, Sendable {
        let cue: Cue
        let exercise: Exercise?
    }

    /// The format every Cue is made in, and the one the audio adapter's player is connected with. 22,050 Hz mono
    /// is what the speech synthesizer produced on a device, so converting only joins its chunks.
    static var format: AVAudioFormat? {
        AVAudioFormat(standardFormatWithSampleRate: 22_050, channels: 1)
    }

    private let lock = NSLock()
    private var buffers: [Sound: AVAudioPCMBuffer] = [:]
    /// Every Sound asked for so far, rendered or not.
    private var wanted = Set(CueSounds.plain.keys.map { Sound(cue: $0, exercise: nil) })
    private var isRendering = false
    /// What every Cue made with a Round Sound is made with. A render under way when it changes is thrown away for
    /// those Cues, which follow with the new one.
    private var roundSound: RoundSound

    init(roundSound: RoundSound = .gong) {
        self.roundSound = roundSound
    }

    /// Switches to `roundSound`, if it's new, and renders again each Cue made with the old one.
    func use(_ roundSound: RoundSound) {
        let changed = lock.withLock {
            guard roundSound != self.roundSound else { return false }
            self.roundSound = roundSound
            buffers = buffers.filter { !CueSounds.usesRoundSound($0.key) }
            return true
        }
        if changed {
            render()
        }
    }

    /// Renders any Sound asked for and not rendered yet, along with `sounds`, unless that's already under way, in which
    /// case it follows once that's done.
    func render(_ sounds: Set<Sound> = []) {
        let missing: (sounds: Set<Sound>, roundSound: RoundSound)? = lock.withLock {
            wanted.formUnion(sounds)
            let missing = wanted.subtracting(buffers.keys)
            guard !isRendering, !missing.isEmpty else { return nil }
            isRendering = true
            return (missing, roundSound)
        }
        guard let missing else { return }
        startRendering(missing.sounds, with: missing.roundSound)
    }

    private func startRendering(_ missing: Set<Sound>, with roundSound: RoundSound) {
        Task { @MainActor in
            let buffers = await CueSounds.render(missing, with: roundSound)
            store(RenderedCues(buffers: buffers, attempted: missing, roundSound: roundSound))
        }
    }

    /// Every Sound saying an Exercise that `workout` might play: each named Work's own, said over its Round Sound, and the
    /// Cue of the Phase before it saying it's next. Whether a Phase has room to say it is the Timeline's call, so
    /// both are rendered.
    static func sounds(for workout: Workout) -> Set<Sound> {
        // A repeating Round follows itself, so its last Phase also comes before its first.
        let phases = workout.phases + workout.repeatingRound + workout.repeatingRound
        var sounds: Set<Sound> = []
        for (index, phase) in phases.enumerated() {
            guard let exercise = phase.exercise else { continue }
            sounds.insert(Sound(cue: .work, exercise: exercise))
            guard index > 0 else { continue }
            let before = phases[index - 1].kind
            guard before != .work else { continue }
            let cue: Cue =
                switch before {
                case .prepare: .prepare
                case .rest: .rest
                case .cooldown: .cooldown
                case .work: .work
                }
            sounds.insert(Sound(cue: cue, exercise: exercise))
        }
        return sounds
    }

    /// The rendered Sound. A missing one starts rendering again, so the next time it's asked for it can be there.
    func buffer(for cue: Cue, saying exercise: Exercise? = nil) -> AVAudioPCMBuffer? {
        let sound = Sound(cue: cue, exercise: exercise)
        if let buffer = lock.withLock({ buffers[sound] }) {
            return buffer
        }
        render([sound])
        return nil
    }

    /// Waits for any rendering under way. It gives up after `limit`, because a Cue problem must never block a
    /// Workout, and any Cue that arrives later still plays.
    func waitForRendering(atMost limit: Duration) async {
        let clock = ContinuousClock()
        let giveUp = clock.now.advanced(by: limit)
        while lock.withLock({ isRendering }), clock.now < giveUp {
            try? await clock.sleep(for: .milliseconds(20))
        }
    }

    /// A Sound that failed to render isn't tried again until it's asked for again, so a voice that's missing can't
    /// keep rendering in a loop. Sounds asked for meanwhile follow at once, still rendering throughout, so a wait
    /// that began before them doesn't end early. Cues made with a Round Sound that's since been replaced are thrown
    /// away and still wanted, so they follow with the new one.
    private func store(_ rendered: RenderedCues) {
        let followUp: (sounds: Set<Sound>, roundSound: RoundSound)? = lock.withLock {
            let stale: Set<Sound> =
                rendered.roundSound == roundSound ? [] : rendered.attempted.filter(CueSounds.usesRoundSound)
            buffers.merge(rendered.buffers.filter { !stale.contains($0.key) }) { _, new in new }
            wanted = Set(buffers.keys).union(wanted.subtracting(rendered.attempted.subtracting(stale)))
            let missing = wanted.subtracting(buffers.keys)
            isRendering = !missing.isEmpty
            return missing.isEmpty ? nil : (missing, roundSound)
        }
        if let followUp {
            startRendering(followUp.sounds, with: followUp.roundSound)
        }
    }
}

/// Carries finished buffers off the main actor. Nothing writes to them after rendering.
private nonisolated struct RenderedCues: @unchecked Sendable {
    let buffers: [CueBank.Sound: AVAudioPCMBuffer]
    let attempted: Set<CueBank.Sound>
    let roundSound: RoundSound
}

/// Makes each Cue's audio: the Round Sound, words in a fixed system voice, or words over the Round Sound.
@MainActor
private enum CueSounds {
    enum Sound {
        case roundSound
        /// One or more utterances. Each starts a second after the one before, so the Countdown's numbers land on
        /// the seconds the running screen shows.
        case words([String])
        case wordsOverRoundSound(String)
    }

    /// A Round's Work starts and ends on the Round Sound, as on a boxing ring's bell. Cooldown and "Workout complete"
    /// also end the last Round's Work, so their words come in over it.
    nonisolated static let plain: [Cue: Sound] = [
        .work: .roundSound,
        .rest: .roundSound,
        .cooldown: .wordsOverRoundSound("Cooldown"),
        .workoutComplete: .wordsOverRoundSound("Workout complete"),
        .tenSeconds: .words(["10 seconds"]),
        .finish: .words(["Finish"]),
        .countdown: .words(["Five", "Four", "Three", "Two", "One"]),
    ]

    /// How a Cue says an Exercise. A Work says it over its Round Sound. Any other Cue says it's next: over the Rest's,
    /// after "Cooldown", or on its own at a Prepare's start. Each fits in the 5 s a Phase leaves after its own Cue.
    nonisolated static func sound(for sound: CueBank.Sound) -> Sound? {
        guard let exercise = sound.exercise else { return plain[sound.cue] }
        switch sound.cue {
        case .work: return .wordsOverRoundSound(exercise.name)
        case .rest: return .wordsOverRoundSound("Next, \(exercise.name)")
        case .cooldown: return .wordsOverRoundSound("Cooldown. Next, \(exercise.name)")
        case .prepare: return .words(["Next, \(exercise.name)"])
        case .workoutComplete, .tenSeconds, .finish, .countdown: return nil
        }
    }

    /// Whether the Round Sound is part of it, so it has to be made again when the owner picks another.
    nonisolated static func usesRoundSound(_ cue: CueBank.Sound) -> Bool {
        switch sound(for: cue) {
        case .roundSound, .wordsOverRoundSound: true
        case .words, nil: false
        }
    }

    static func render(
        _ wanted: Set<CueBank.Sound>, with roundSound: RoundSound
    ) async -> [CueBank.Sound: AVAudioPCMBuffer] {
        var rendered: [CueBank.Sound: AVAudioPCMBuffer] = [:]
        let synthesizer = AVSpeechSynthesizer()
        let bare = CueBank.format.flatMap(roundSound.sound(in:))
        for cue in wanted {
            guard let sound = sound(for: cue) else { continue }
            switch sound {
            case .roundSound:
                rendered[cue] = bare
            case .words(let utterances):
                var buffers: [AVAudioPCMBuffer] = []
                for words in utterances {
                    guard let buffer = joined(await chunks(of: words, from: synthesizer)) else { break }
                    buffers.append(buffer)
                }
                if buffers.count == utterances.count {
                    rendered[cue] = spacedOneSecondApart(buffers)
                }
            case .wordsOverRoundSound(let words):
                rendered[cue] = joined(await chunks(of: words, from: synthesizer)).flatMap(roundSound.sound(under:))
            }
        }
        return rendered
    }

    /// One buffer that starts each utterance a whole second after the one before and ends with the last. An utterance
    /// longer than a second is cut there, so the numbers never drift off the seconds.
    private nonisolated static func spacedOneSecondApart(_ buffers: [AVAudioPCMBuffer]) -> AVAudioPCMBuffer? {
        guard buffers.count > 1 else { return buffers.first }
        guard let format = CueBank.format, let last = buffers.last else { return nil }
        let second = AVAudioFrameCount(format.sampleRate)
        let length = second * AVAudioFrameCount(buffers.count - 1) + last.frameLength
        guard let spaced = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: length),
            let target = spaced.floatChannelData?[0]
        else { return nil }
        spaced.frameLength = length
        target.update(repeating: 0, count: Int(length))
        for (index, buffer) in buffers.enumerated() {
            guard let source = buffer.floatChannelData?[0] else { return nil }
            let frames = index == buffers.count - 1 ? buffer.frameLength : min(buffer.frameLength, second)
            (target + Int(second) * index).update(from: source, count: Int(frames))
        }
        return spaced
    }

    private static func chunks(of words: String, from synthesizer: AVSpeechSynthesizer) async -> [AVAudioPCMBuffer] {
        let collector = ChunkCollector()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let utterance = AVSpeechUtterance(string: words)
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            synthesizer.write(utterance, toBufferCallback: collecting(into: collector, then: continuation))
        }
        return collector.chunks
    }

    /// Nonisolated, because the synthesizer doesn't promise which thread it calls this on.
    private nonisolated static func collecting(
        into collector: ChunkCollector,
        then continuation: CheckedContinuation<Void, Never>
    ) -> @Sendable (AVAudioBuffer) -> Void {
        { buffer in
            guard !collector.isDone, let pcm = buffer as? AVAudioPCMBuffer else { return }
            if pcm.frameLength == 0 {
                collector.isDone = true
                continuation.resume()
            } else {
                collector.chunks.append(pcm)
            }
        }
    }

    /// One buffer in the standard format. The converter takes the chunks one after another.
    private nonisolated static func joined(_ chunks: [AVAudioPCMBuffer]) -> AVAudioPCMBuffer? {
        guard let source = chunks.first?.format, let target = CueBank.format,
            let converter = AVAudioConverter(from: source, to: target)
        else { return nil }
        let frames = chunks.reduce(0.0) { $0 + Double($1.frameLength) }
        let capacity = AVAudioFrameCount((frames * target.sampleRate / source.sampleRate).rounded(.up)) + 1024
        guard let joined = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return nil }

        nonisolated(unsafe) var remaining = chunks[...]
        var error: NSError?
        converter.convert(to: joined, error: &error) { _, status in
            guard let next = remaining.popFirst() else {
                status.pointee = .endOfStream
                return nil
            }
            status.pointee = .haveData
            return next
        }
        return error == nil && joined.frameLength > 0 ? joined : nil
    }
}

/// The synthesizer delivers its chunks one at a time, in order, and nothing reads them until it's done.
private nonisolated final class ChunkCollector: @unchecked Sendable {
    var chunks: [AVAudioPCMBuffer] = []
    var isDone = false
}
