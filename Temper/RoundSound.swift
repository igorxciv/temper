import AVFAudio

/// The sound a Round's Work starts and ends on, which Cooldown and "Workout complete" are also spoken over. The owner
/// picks it in Settings, so a gong that grates can give way to something quieter. Each is made from sine waves, so
/// no recording ships with the app.
///
/// The raw value is what's saved, so renaming a case forgets the owner's choice.
nonisolated enum RoundSound: String, CaseIterable, Sendable {
    /// A boxing ring's bell.
    case gong
    /// A soft, bright bell, quieter than the gong.
    case chime
    /// Two short electronic pips.
    case beep

    /// How far into the sound any words start, once its attack has passed.
    private static let wordsOffset = 0.45

    var name: String {
        switch self {
        case .gong: "Gong"
        case .chime: "Chime"
        case .beep: "Beep"
        }
    }

    /// The sound alone, in `format`, which has to be mono floats. None lasts longer than the gong's 1.6 s, so a Cue
    /// never runs into the next one in the shortest Phase, 00:05.
    func sound(in format: AVAudioFormat) -> AVAudioPCMBuffer? {
        switch self {
        case .gong: Gong.strike(in: format)
        case .chime: Chime.strike(in: format)
        case .beep: Beep.pips(in: format)
        }
    }

    /// The sound with `words` coming in over its tail, in their format. Too loud a sum is scaled down to fit.
    func sound(under words: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let sound = sound(in: words.format), let soundSamples = sound.floatChannelData?[0],
            let wordSamples = words.floatChannelData?[0]
        else { return nil }
        let offset = Int(Self.wordsOffset * words.format.sampleRate)
        let frames = max(Int(sound.frameLength), offset + Int(words.frameLength))
        guard let mixed = AVAudioPCMBuffer(pcmFormat: words.format, frameCapacity: AVAudioFrameCount(frames)),
            let samples = mixed.floatChannelData?[0]
        else { return nil }
        mixed.frameLength = AVAudioFrameCount(frames)

        var loudest: Float = 0
        for frame in 0..<frames {
            let tone = frame < Int(sound.frameLength) ? soundSamples[frame] : 0
            let word = (offset..<offset + Int(words.frameLength)).contains(frame) ? wordSamples[frame - offset] : 0
            samples[frame] = tone + word
            loudest = max(loudest, abs(tone + word))
        }
        if loudest > 1 {
            for frame in 0..<frames {
                samples[frame] /= loudest
            }
        }
        return mixed
    }

    /// `seconds` of `sample(time)`, in `format`, which has to be mono floats, scaled so its loudest sample is `peak`.
    static func synthesize(
        in format: AVAudioFormat, seconds: Double, peak: Float, sample: (Double) -> Double
    ) -> AVAudioPCMBuffer? {
        let rate = format.sampleRate
        let frames = AVAudioFrameCount(seconds * rate)
        guard format.channelCount == 1, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
            let samples = buffer.floatChannelData?[0]
        else { return nil }
        buffer.frameLength = frames

        var loudest: Float = 0
        for frame in 0..<Int(frames) {
            let value = Float(sample(Double(frame) / rate))
            samples[frame] = value
            loudest = max(loudest, abs(value))
        }
        guard loudest > 0 else { return nil }
        for frame in 0..<Int(frames) {
            samples[frame] *= peak / loudest
        }
        return buffer
    }
}

/// A partial of a struck bell: its frequency as a multiple of the fundamental, its starting level, and the seconds
/// it takes to fall to 1/e.
nonisolated struct Partial {
    let ratio: Double
    let level: Double
    let decay: Double

    func value(at time: Double, over fundamental: Double) -> Double {
        level * exp(-time / decay) * sin(2 * .pi * fundamental * ratio * time)
    }
}

/// A small glass-like bell, struck softly: no hammer click, a gentler attack, and a lower peak than the gong.
nonisolated enum Chime {
    /// C6, in Hz.
    private static let fundamental = 1046.5
    /// The second partial sits just above the first, so the two beat slowly, and the third adds a little brightness.
    private static let partials = [
        Partial(ratio: 1, level: 1, decay: 0.45),
        Partial(ratio: 1.002, level: 0.5, decay: 0.45),
        Partial(ratio: 3, level: 0.12, decay: 0.15),
    ]
    private static let attack = 0.006
    private static let length = 1.2
    private static let fadeOut = 0.3
    private static let peak: Float = 0.6

    static func strike(in format: AVAudioFormat) -> AVAudioPCMBuffer? {
        RoundSound.synthesize(in: format, seconds: length, peak: peak) { time in
            let ring = partials.reduce(0.0) { $0 + $1.value(at: time, over: fundamental) }
            return ring * min(1, time / attack) * min(1, (length - time) / fadeOut)
        }
    }
}

/// Two short pips, like a sports watch's, with a touch of the third harmonic so they carry over music.
nonisolated enum Beep {
    /// B5, in Hz.
    private static let frequency = 987.8
    private static let pip = 0.12
    private static let gap = 0.08
    /// A ramp this long at each edge of a pip keeps it from clicking.
    private static let ramp = 0.005
    /// A little silence after the second pip, so the sound ends on silence, as the bells do.
    private static let length = pip * 2 + gap + 0.02
    private static let peak: Float = 0.6

    static func pips(in format: AVAudioFormat) -> AVAudioPCMBuffer? {
        RoundSound.synthesize(in: format, seconds: length, peak: peak) { time in
            let start = time < pip + gap ? 0 : pip + gap
            let into = time - start
            guard into < pip else { return 0 }
            let envelope = min(1, into / ramp, (pip - into) / ramp)
            let phase = 2 * .pi * frequency * time
            return envelope * (sin(phase) + 0.15 * sin(3 * phase))
        }
    }
}
