import TemperCore
import Testing

@testable import Temper

struct TemperAppTests {
    @Test func `The app reaches Workout through TemperCore`() {
        #expect(TemperApp.placeholderWorkout.phases.count == 2)
    }
}
