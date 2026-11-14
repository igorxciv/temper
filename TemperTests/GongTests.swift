import AVFAudio
import Testing

@testable import Temper

struct GongTests {
    private let format = AVAudioFormat(standardFormatWithSampleRate: 22_050, channels: 1)!

    @Test func `The strike sounds at once, so the Cue is heard at its deadline`() throws {
        let gong = try #require(Gong.strike(in: format))
        let samples = try #require(gong.floatChannelData?[0])
        let firstAudible = (0..<Int(gong.frameLength)).first { abs(samples[$0]) > 0.001 }
        #expect(try #require(firstAudible) < Int(0.005 * format.sampleRate))
    }

    @Test func `The strike rings out within 1.6 s and never clips`() throws {
        let gong = try #require(Gong.strike(in: format))
        let samples = try #require(gong.floatChannelData?[0])
        let frames = Int(gong.frameLength)
        #expect(Double(frames) / format.sampleRate <= 1.6)
        #expect((0..<frames).allSatisfy { abs(samples[$0]) <= 1 })
        #expect(abs(samples[frames - 1]) < 0.001)
    }

    @Test func `Words start 0.45 s into the strike, over its tail`() throws {
        let wordFrames = AVAudioFrameCount(1.5 * format.sampleRate)
        let words = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: wordFrames))
        words.frameLength = wordFrames
        let wordSamples = try #require(words.floatChannelData?[0])
        for frame in 0..<Int(wordFrames) {
            wordSamples[frame] = 0.9
        }

        let mixed = try #require(Gong.strike(under: words))
        let samples = try #require(mixed.floatChannelData?[0])
        #expect(mixed.frameLength == wordFrames + AVAudioFrameCount(0.45 * format.sampleRate))
        #expect((0..<Int(mixed.frameLength)).allSatisfy { abs(samples[$0]) <= 1 })
    }

    @Test func `The strike needs mono audio`() throws {
        let stereo = try #require(AVAudioFormat(standardFormatWithSampleRate: 22_050, channels: 2))
        #expect(Gong.strike(in: stereo) == nil)
    }
}
