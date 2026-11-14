import AVFAudio

/// One strike of a boxing ring's bell, made from the partials of a struck metal dome, so no recording ships with
/// the app.
nonisolated enum Gong {
    /// The bell's lowest partial, in Hz.
    private static let fundamental = 820.0
    /// Each partial's frequency as a multiple of the fundamental, its starting level, and the seconds it takes to
    /// fall to 1/e. The second sits just above the fundamental, so the two beat the way a real bell shimmers.
    private static let partials: [(ratio: Double, level: Double, decay: Double)] = [
        (1, 1, 0.55),
        (1.004, 0.6, 0.5),
        (2.76, 0.5, 0.3),
        (5.4, 0.3, 0.15),
        (8.93, 0.15, 0.07),
    ]
    /// The hammer's click, a burst of noise this loud next to the partials, falling to 1/e in `clickDecay`.
    private static let clickLevel = 0.3
    private static let clickDecay = 0.004
    /// A ramp this long keeps the first sample from popping.
    private static let attack = 0.002
    /// Kept short, so a Cue never runs into the next one in the shortest Phase, 00:05.
    private static let length = 1.6
    private static let fadeOut = 0.25
    private static let peak: Float = 0.8
    /// How far into the strike any words start, once the clang has rung out.
    private static let wordsOffset = 0.45

    /// The strike alone, in `format`, which has to be mono floats.
    static func strike(in format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let rate = format.sampleRate
        let frames = AVAudioFrameCount(length * rate)
        guard format.channelCount == 1, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
            let samples = buffer.floatChannelData?[0]
        else { return nil }
        buffer.frameLength = frames

        // A fixed seed, so the click sounds the same every time.
        var noise = SplitMix(seed: 0x6F6E_67)
        var loudest: Float = 0
        for frame in 0..<Int(frames) {
            let time = Double(frame) / rate
            let ring = partials.reduce(0.0) { sum, partial in
                sum + partial.level * exp(-time / partial.decay)
                    * sin(2 * .pi * fundamental * partial.ratio * time)
            }
            let click = clickLevel * exp(-time / clickDecay) * noise.nextSigned()
            let envelope = min(1, time / attack) * min(1, (length - time) / fadeOut)
            let sample = Float((ring + click) * envelope)
            samples[frame] = sample
            loudest = max(loudest, abs(sample))
        }
        guard loudest > 0 else { return nil }
        for frame in 0..<Int(frames) {
            samples[frame] *= peak / loudest
        }
        return buffer
    }

    /// The strike with `words` coming in over its tail, in their format. Too loud a sum is scaled down to fit.
    static func strike(under words: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let gong = strike(in: words.format), let gongSamples = gong.floatChannelData?[0],
            let wordSamples = words.floatChannelData?[0]
        else { return nil }
        let offset = Int(wordsOffset * words.format.sampleRate)
        let frames = max(Int(gong.frameLength), offset + Int(words.frameLength))
        guard let mixed = AVAudioPCMBuffer(pcmFormat: words.format, frameCapacity: AVAudioFrameCount(frames)),
            let samples = mixed.floatChannelData?[0]
        else { return nil }
        mixed.frameLength = AVAudioFrameCount(frames)

        var loudest: Float = 0
        for frame in 0..<frames {
            let ring = frame < Int(gong.frameLength) ? gongSamples[frame] : 0
            let word = (offset..<offset + Int(words.frameLength)).contains(frame) ? wordSamples[frame - offset] : 0
            samples[frame] = ring + word
            loudest = max(loudest, abs(ring + word))
        }
        if loudest > 1 {
            for frame in 0..<frames {
                samples[frame] /= loudest
            }
        }
        return mixed
    }
}

/// A small seeded generator, so the hammer's click is the same noise on every render.
private nonisolated struct SplitMix {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    /// A value from -1 to 1.
    mutating func nextSigned() -> Double {
        state &+= 0x9E37_79B9_7F4A_7C15
        var mixed = state
        mixed = (mixed ^ (mixed >> 30)) &* 0xBF58_476D_1CE4_E5B9
        mixed = (mixed ^ (mixed >> 27)) &* 0x94D0_49BB_1331_11EB
        mixed ^= mixed >> 31
        return Double(mixed >> 11) / Double(1 << 52) - 1
    }
}
