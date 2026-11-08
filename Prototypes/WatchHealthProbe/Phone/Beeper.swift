// PROBE, throwaway. Keeps a `.playback` session and an engine running, so the app runs while locked as Temper
// does during a Workout, and plays a short beep at each stand-in Phase.

import AVFAudio

final class Beeper {
    private let engine = AVAudioEngine()
    private let silence = AVAudioPlayerNode()
    private let tone = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1) ?? AVAudioFormat()
    private lazy var quiet = Self.buffer(format: format, seconds: 0.5) { _ in 0 }
    private lazy var beep = Self.buffer(format: format, seconds: 0.12) { t in
        let fade = min(1, min(t, 0.12 - t) / 0.01)
        return Float(sin(2 * .pi * 1_000 * t) * 0.6 * fade)
    }
    private var observers: [any NSObjectProtocol] = []
    private(set) var isRunning = false
    var onEvent: (String) -> Void = { _ in }

    init() {
        engine.attach(silence)
        engine.attach(tone)
        engine.connect(silence, to: engine.mainMixerNode, format: format)
        engine.connect(tone, to: engine.mainMixerNode, format: format)
        let center = NotificationCenter.default
        observers.append(
            center.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) {
                [weak self] _ in
                MainActor.assumeIsolated { self?.restart(reason: "engine configuration change") }
            })
        observers.append(
            center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) {
                [weak self] note in
                let type = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
                MainActor.assumeIsolated {
                    if type == AVAudioSession.InterruptionType.ended.rawValue {
                        self?.restart(reason: "interruption ended")
                    } else {
                        self?.onEvent("audio interrupted")
                    }
                }
            })
    }

    func start() {
        guard !isRunning else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, options: [.mixWithOthers])
            try session.setActive(true)
            try engine.start()
            if let quiet { silence.scheduleBuffer(quiet, at: nil, options: .loops) }
            silence.play()
            tone.play()
            isRunning = true
            onEvent("audio running")
        } catch {
            onEvent("audio failed to start: \(error)")
        }
    }

    func stop() {
        guard isRunning else { return }
        silence.stop()
        tone.stop()
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        isRunning = false
        onEvent("audio stopped")
    }

    func play() {
        guard isRunning, let beep else { return }
        tone.scheduleBuffer(beep, at: nil, options: .interrupts)
    }

    private func restart(reason: String) {
        guard isRunning else { return }
        isRunning = false
        onEvent("audio restarting after \(reason)")
        start()
    }

    private static func buffer(
        format: AVAudioFormat, seconds: Double, sample: (Double) -> Float
    ) -> AVAudioPCMBuffer? {
        let frames = AVAudioFrameCount(seconds * format.sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
            let channels = buffer.floatChannelData
        else { return nil }
        buffer.frameLength = frames
        let channel = channels[0]
        for frame in 0..<Int(frames) {
            channel[frame] = sample(Double(frame) / format.sampleRate)
        }
        return buffer
    }
}
