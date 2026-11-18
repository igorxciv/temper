import AVFAudio
import Foundation
import Testing

@testable import Temper

struct RoundSoundTests {
    private let format = AVAudioFormat(standardFormatWithSampleRate: 22_050, channels: 1)!

    @Test(arguments: RoundSound.allCases)
    func `Each Round Sound sounds at once, so the Cue is heard at its deadline`(sound: RoundSound) throws {
        let buffer = try #require(sound.sound(in: format))
        let samples = try #require(buffer.floatChannelData?[0])
        let firstAudible = (0..<Int(buffer.frameLength)).first { abs(samples[$0]) > 0.001 }
        #expect(try #require(firstAudible) < Int(0.005 * format.sampleRate))
    }

    @Test(arguments: RoundSound.allCases)
    func `Each Round Sound ends within the gong's 1.6 s and never clips`(sound: RoundSound) throws {
        let buffer = try #require(sound.sound(in: format))
        let samples = try #require(buffer.floatChannelData?[0])
        let frames = Int(buffer.frameLength)
        #expect(Double(frames) / format.sampleRate <= 1.6)
        #expect((0..<frames).allSatisfy { abs(samples[$0]) <= 1 })
        #expect(abs(samples[frames - 1]) < 0.001)
    }

    @Test(arguments: RoundSound.allCases)
    func `Words start 0.45 s into each Round Sound, over its tail`(sound: RoundSound) throws {
        let wordFrames = AVAudioFrameCount(1.5 * format.sampleRate)
        let words = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: wordFrames))
        words.frameLength = wordFrames
        let wordSamples = try #require(words.floatChannelData?[0])
        for frame in 0..<Int(wordFrames) {
            wordSamples[frame] = 0.9
        }

        let mixed = try #require(sound.sound(under: words))
        let samples = try #require(mixed.floatChannelData?[0])
        #expect(mixed.frameLength == wordFrames + AVAudioFrameCount(0.45 * format.sampleRate))
        #expect((0..<Int(mixed.frameLength)).allSatisfy { abs(samples[$0]) <= 1 })
    }

    @Test(arguments: RoundSound.allCases)
    func `Each Round Sound needs mono audio`(sound: RoundSound) throws {
        let stereo = try #require(AVAudioFormat(standardFormatWithSampleRate: 22_050, channels: 2))
        #expect(sound.sound(in: stereo) == nil)
    }

    @Test func `The Round Sound is the gong until the owner picks another, and stays as they left it after a relaunch`()
        throws
    {
        let suite = "TemperTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let setting = RoundSoundSetting(defaults: defaults)
        #expect(setting.sound == .gong)

        setting.sound = .chime

        #expect(RoundSoundSetting(defaults: defaults).sound == .chime)
    }

    @Test func `A saved Round Sound that no longer exists falls back to the gong`() throws {
        let suite = "TemperTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("whistle", forKey: RoundSoundSetting.soundKey)

        #expect(RoundSoundSetting(defaults: defaults).sound == .gong)
    }
}
