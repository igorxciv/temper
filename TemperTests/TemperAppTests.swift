import TemperCore
import Testing

@testable import Temper

struct TemperAppTests {
    @Test func `The app runs the first-launch Workout until setup arrives`() {
        #expect(TemperApp.fixedWorkout == WorkoutSettings.firstLaunch.makeWorkout())
    }
}
