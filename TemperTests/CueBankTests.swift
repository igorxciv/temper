import AVFAudio
import TemperCore
import Testing

@testable import Temper

struct CueBankTests {
    /// The longest name an Exercise keeps.
    private let longestName = String(repeating: "Kettlebell ", count: 3)

    private func rendered(_ cue: Cue, saying exercise: Exercise) async throws -> AVAudioPCMBuffer {
        let bank = CueBank()
        bank.render([CueBank.Sound(cue: cue, exercise: exercise)])
        await bank.waitForRendering(atMost: .seconds(30))
        return try #require(bank.buffer(for: cue, saying: exercise))
    }

    private func seconds(_ buffer: AVAudioPCMBuffer) -> Double {
        Double(buffer.frameLength) / buffer.format.sampleRate
    }

    /// A Phase leaves 5 s after its own Cue before its Countdown, so every Cue that says an Exercise must end within
    /// that. "Cooldown. Next, …" over the gong is the longest.
    @Test(arguments: [Cue.cooldown, .rest, .work, .prepare])
    func `Every Cue saying the longest Exercise ends within the 5s a Phase leaves for it`(cue: Cue) async throws {
        let longest = try #require(Exercise(longestName))
        #expect(longest.name.count == Exercise.maximumLength)
        let buffer = try await rendered(cue, saying: longest)

        #expect(seconds(buffer) <= 5)
    }

    private func frames(of roundSound: RoundSound) throws -> AVAudioFrameCount {
        let format = try #require(CueBank.format)
        return try #require(roundSound.sound(in: format)).frameLength
    }

    @Test func `A new Round Sound replaces the Work and Rest Cues, and leaves the spoken ones as they were`()
        async throws
    {
        let bank = CueBank(roundSound: .gong)
        bank.render()
        await bank.waitForRendering(atMost: .seconds(30))
        let countdown = try #require(bank.buffer(for: .countdown))
        #expect(try #require(bank.buffer(for: .work)).frameLength == frames(of: .gong))

        bank.use(.beep)
        await bank.waitForRendering(atMost: .seconds(30))

        #expect(try #require(bank.buffer(for: .work)).frameLength == frames(of: .beep))
        #expect(try #require(bank.buffer(for: .rest)).frameLength == frames(of: .beep))
        #expect(bank.buffer(for: .countdown) === countdown)
    }

    @Test func `A Round Sound picked while the Cues are rendering still ends up in them`() async throws {
        let bank = CueBank(roundSound: .gong)
        bank.render()
        bank.use(.chime)
        await bank.waitForRendering(atMost: .seconds(30))

        #expect(try #require(bank.buffer(for: .work)).frameLength == frames(of: .chime))
        #expect(bank.buffer(for: .cooldown) != nil)
    }

    @Test func `A Workout's named sounds are each Work's own and the Cue of the Phase before it`() throws {
        let squats = try #require(Exercise("Squats"))
        let pushUps = try #require(Exercise("Push-ups"))
        let workout = Workout(phases: [
            Phase(kind: .prepare, duration: .seconds(10)),
            Phase(kind: .work, duration: .seconds(30), round: 1, exercise: squats),
            Phase(kind: .work, duration: .seconds(30), round: 1, exercise: pushUps),
            Phase(kind: .rest, duration: .seconds(15), round: 1),
            Phase(kind: .work, duration: .seconds(30), round: 2, exercise: squats),
        ])

        #expect(
            CueBank.sounds(for: workout) == [
                CueBank.Sound(cue: .work, exercise: squats),
                CueBank.Sound(cue: .prepare, exercise: squats),
                CueBank.Sound(cue: .work, exercise: pushUps),
                CueBank.Sound(cue: .rest, exercise: squats),
            ])
    }
}
