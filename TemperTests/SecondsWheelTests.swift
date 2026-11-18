import Foundation
import Testing

@testable import Temper

struct SecondsWheelTests {
    @Test func `Seconds come in steps of 5 until the owner asks for every second, and stay so after a relaunch`()
        throws
    {
        let suite = "TemperTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let wheel = SecondsWheel(defaults: defaults)
        #expect(!wheel.offersEverySecond)

        wheel.offersEverySecond = true

        #expect(SecondsWheel(defaults: defaults).offersEverySecond)
    }
}
