import AVFAudio

// The calm, low Round Sounds. An iPhone's own speaker gives little below 200 Hz, so each carries overtones that
// let the ear hear its low note there, and headphones bring out the bass itself.

/// A struck singing bowl: a low, slow ring whose paired partials beat a few times a second, so it shimmers.
nonisolated enum Bowl {
    /// A3, in Hz.
    private static let fundamental = 220.0
    /// Each mode of a bowl comes as a close pair, so the first two beat at 2.6 Hz and the next two at 4.4 Hz.
    private static let partials = [
        Partial(ratio: 1, level: 1, decay: 1),
        Partial(ratio: 1.012, level: 0.8, decay: 1),
        Partial(ratio: 2.78, level: 0.55, decay: 0.6),
        Partial(ratio: 2.8, level: 0.4, decay: 0.6),
        Partial(ratio: 5.2, level: 0.15, decay: 0.25),
    ]
    /// Struck with a soft mallet, so it swells in rather than clanging.
    private static let attack = 0.015
    private static let length = 1.6
    private static let fadeOut = 0.6
    private static let peak: Float = 0.6

    static func strike(in format: AVAudioFormat) -> AVAudioPCMBuffer? {
        RoundSound.synthesize(in: format, seconds: length, peak: peak) { time in
            let ring = partials.reduce(0.0) { $0 + $1.value(at: time, over: fundamental) }
            return ring * min(1, time / attack) * min(1, (length - time) / fadeOut)
        }
    }
}

/// A low marimba note: a warm wooden knock whose overtones die quickly, leaving the low note to ring.
nonisolated enum Marimba {
    /// G3, in Hz.
    private static let fundamental = 196.0
    /// A marimba bar's overtones sit near 4 and 9.2 times its note. The octave stands in for the resonator's
    /// warmth, and carries the note on the iPhone's speaker.
    private static let partials = [
        Partial(ratio: 1, level: 1, decay: 0.6),
        Partial(ratio: 2, level: 0.5, decay: 0.4),
        Partial(ratio: 3.93, level: 0.5, decay: 0.15),
        Partial(ratio: 9.2, level: 0.12, decay: 0.04),
    ]
    private static let attack = 0.002
    private static let length = 1.2
    private static let fadeOut = 0.4
    private static let peak: Float = 0.65

    static func strike(in format: AVAudioFormat) -> AVAudioPCMBuffer? {
        RoundSound.synthesize(in: format, seconds: length, peak: peak) { time in
            let ring = partials.reduce(0.0) { $0 + $1.value(at: time, over: fundamental) }
            return ring * min(1, time / attack) * min(1, (length - time) / fadeOut)
        }
    }
}

/// A soft, deep drum: a felt-beater thump whose pitch falls from 140 Hz to 80 Hz as it dies away.
nonisolated enum Drum {
    /// Where the pitch settles, and how far above it the hit starts, in Hz.
    private static let settled = 80.0
    private static let drop = 60.0
    /// The seconds the pitch takes to fall most of the way, to 1/e of `drop` above `settled`.
    private static let dropTime = 0.04
    /// Each harmonic's multiple of the pitch, starting level, and seconds to fall to 1/e. The upper ones die fast,
    /// so the hit has an edge the iPhone's speaker can play and the tail is all bass.
    private static let harmonics: [(multiple: Double, level: Double, decay: Double)] = [
        (1, 1, 0.3),
        (2, 0.9, 0.2),
        (3, 0.8, 0.12),
        (4, 0.6, 0.08),
        (5, 0.45, 0.06),
        (6, 0.3, 0.04),
    ]
    private static let attack = 0.002
    private static let length = 1.0
    private static let fadeOut = 0.3
    private static let peak: Float = 0.8

    static func hit(in format: AVAudioFormat) -> AVAudioPCMBuffer? {
        RoundSound.synthesize(in: format, seconds: length, peak: peak) { time in
            // The phase is the falling pitch summed over time.
            let phase = 2 * .pi * (settled * time + drop * dropTime * (1 - exp(-time / dropTime)))
            let body = harmonics.reduce(0.0) { sum, harmonic in
                sum + harmonic.level * exp(-time / harmonic.decay) * sin(harmonic.multiple * phase)
            }
            return body * min(1, time / attack) * min(1, (length - time) / fadeOut)
        }
    }
}
