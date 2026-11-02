// PROTOTYPE, throw away. Renders the spoken Cues once, in the foreground, to PCM buffers.
import AVFAudio

struct CueBank: @unchecked Sendable {
    let buffers: [String: AVAudioPCMBuffer]
    let sourceFormat: String
    let renderSeconds: Double
    var format: AVAudioFormat? { buffers.values.first?.format }
}

@MainActor
enum CueRenderer {
    static let words = ["Work", "Rest", "Cooldown", "Workout complete"]
    private static var keepAlive: AVSpeechSynthesizer?

    static func render() async -> CueBank {
        var buffers: [String: AVAudioPCMBuffer] = [:]
        var source = "?"
        let clock = ContinuousClock()
        let begin = clock.now
        let synth = AVSpeechSynthesizer()
        keepAlive = synth
        for word in words {
            let chunks = await chunks(for: word, synth: synth)
            guard let first = chunks.first else { continue }
            source = first.format.description
            if let joined = join(chunks), let standard = standardize(joined) {
                buffers[word] = standard
            }
        }
        return CueBank(
            buffers: buffers, sourceFormat: source,
            renderSeconds: RunLog.seconds(begin.duration(to: clock.now)))
    }

    private final class Collector: @unchecked Sendable {
        var chunks: [AVAudioPCMBuffer] = []
        var done = false
    }

    private static func chunks(for word: String, synth: AVSpeechSynthesizer) async
        -> [AVAudioPCMBuffer]
    {
        let collector = Collector()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let utterance = AVSpeechUtterance(string: word)
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            synth.write(utterance) { buffer in
                guard !collector.done, let pcm = buffer as? AVAudioPCMBuffer else { return }
                if pcm.frameLength == 0 {
                    collector.done = true
                    continuation.resume()
                } else {
                    collector.chunks.append(pcm)
                }
            }
        }
        return collector.chunks
    }

    private static func join(_ chunks: [AVAudioPCMBuffer]) -> AVAudioPCMBuffer? {
        guard let format = chunks.first?.format else { return nil }
        let total = chunks.reduce(AVAudioFrameCount(0)) { $0 + $1.frameLength }
        guard let out = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: total) else {
            return nil
        }
        let size = Int(format.streamDescription.pointee.mBytesPerFrame)
        var offset = 0
        let list = UnsafeMutableAudioBufferListPointer(out.mutableAudioBufferList)
        for chunk in chunks {
            let source = UnsafeMutableAudioBufferListPointer(chunk.mutableAudioBufferList)
            for index in 0..<list.count {
                memcpy(
                    list[index].mData! + offset * size, source[index].mData!,
                    Int(chunk.frameLength) * size)
            }
            offset += Int(chunk.frameLength)
        }
        out.frameLength = total
        return out
    }

    private static func standardize(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard
            let target = AVAudioFormat(
                standardFormatWithSampleRate: buffer.format.sampleRate, channels: 1)
        else { return nil }
        if buffer.format == target { return buffer }
        guard let converter = AVAudioConverter(from: buffer.format, to: target),
            let out = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: buffer.frameLength)
        else { return nil }
        nonisolated(unsafe) let input = buffer
        nonisolated(unsafe) var consumed = false
        var error: NSError?
        converter.convert(to: out, error: &error) { _, status in
            if consumed {
                status.pointee = .endOfStream
                return nil
            }
            consumed = true
            status.pointee = .haveData
            return input
        }
        return error == nil ? out : nil
    }
}
