import AVFAudio
import TemperCore

/// The spoken Cues, rendered once and kept in memory only. It outlives any one Workout.
///
/// A class with a lock, because the audio adapter has to read it without suspending. Buffers are never written
/// to after rendering.
nonisolated final class CueBank: @unchecked Sendable {
    /// The format every Cue is converted to, and the one the audio adapter's player is connected with. 22,050 Hz
    /// mono is what the speech synthesizer produced on a device, so converting only joins its chunks.
    static var format: AVAudioFormat? {
        AVAudioFormat(standardFormatWithSampleRate: 22_050, channels: 1)
    }

    private let lock = NSLock()
    private var buffers: [Cue: AVAudioPCMBuffer] = [:]
    private var isRendering = false
    private var seconds: Double?

    /// How long the last rendering took, for the timing log.
    var renderSeconds: Double? {
        lock.withLock { seconds }
    }

    /// Renders any Cue not rendered yet, unless that's already under way.
    func render() {
        let started = lock.withLock {
            guard !isRendering, buffers.count < CueSpeech.all.count else { return false }
            isRendering = true
            return true
        }
        guard started else { return }
        Task { @MainActor in
            let clock = ContinuousClock()
            let begin = clock.now
            let rendered = await CueSpeech.render()
            let took = begin.duration(to: clock.now) / .seconds(1)
            store(RenderedCues(buffers: rendered), took: took)
        }
    }

    /// The rendered Cue. A missing one starts rendering again, so the next time it's asked for it can be there.
    func buffer(for cue: Cue) -> AVAudioPCMBuffer? {
        if let buffer = lock.withLock({ buffers[cue] }) {
            return buffer
        }
        render()
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

    private func store(_ rendered: RenderedCues, took: Double) {
        lock.withLock {
            buffers.merge(rendered.buffers) { _, new in new }
            seconds = took
            isRendering = false
        }
    }
}

/// Carries finished buffers off the main actor. Nothing writes to them after rendering.
private nonisolated struct RenderedCues: @unchecked Sendable {
    let buffers: [Cue: AVAudioPCMBuffer]
}

/// Turns each Cue's words into audio with a fixed system voice.
@MainActor
private enum CueSpeech {
    nonisolated static let all: [Cue: String] = [
        .work: "Work",
        .rest: "Rest",
        .cooldown: "Cooldown",
        .workoutComplete: "Workout complete",
        .tenSeconds: "10 seconds",
    ]

    static func render() async -> [Cue: AVAudioPCMBuffer] {
        var rendered: [Cue: AVAudioPCMBuffer] = [:]
        let synthesizer = AVSpeechSynthesizer()
        for (cue, words) in all {
            let chunks = await chunks(of: words, from: synthesizer)
            rendered[cue] = joined(chunks)
        }
        return rendered
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
