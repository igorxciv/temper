import Foundation
import Testing

@testable import Temper

struct MusicLoweringTests {
    @Test func `Lowering music is on until the owner turns it off, and stays as they left it after a relaunch`() throws
    {
        let suite = "TemperTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let lowering = MusicLowering(defaults: defaults)
        #expect(lowering.isOn)

        lowering.isOn = false

        #expect(!MusicLowering(defaults: defaults).isOn)
    }
}
