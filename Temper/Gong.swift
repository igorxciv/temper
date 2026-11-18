import AVFAudio

/// One strike of a boxing ring's bell, made from the partials of a struck metal dome, so no recording ships with
/// the app.
nonisolated enum Gong {
    /// The bell's lowest partial, in Hz.
    private static let fundamental = 820.0
    /// The second partial sits just above the fundamental, so the two beat the way a real bell shimmers.
    private static let partials = [
        Partial(ratio: 1, level: 1, decay: 0.55),
        Partial(ratio: 1.004, level: 0.6, decay: 0.5),
        Partial(ratio: 2.76, level: 0.5, decay: 0.3),
        Partial(ratio: 5.4, level: 0.3, decay: 0.15),
        Partial(ratio: 8.93, level: 0.15, decay: 0.07),
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

    /// The strike alone, in `format`, which has to be mono floats.
    static func strike(in format: AVAudioFormat) -> AVAudioPCMBuffer? {
        // A fixed seed, so the click sounds the same every time.
        var noise = SplitMix(seed: 0x6F6E_67)
        return RoundSound.synthesize(in: format, seconds: length, peak: peak) { time in
            let ring = partials.reduce(0.0) { $0 + $1.value(at: time, over: fundamental) }
            let click = clickLevel * exp(-time / clickDecay) * noise.nextSigned()
            return (ring + click) * min(1, time / attack) * min(1, (length - time) / fadeOut)
        }
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
