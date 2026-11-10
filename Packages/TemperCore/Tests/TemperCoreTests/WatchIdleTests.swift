import Testing

@testable import TemperCore

struct WatchIdleTests {
    @Test func `With workouts allowed, the idle Watch sends the owner to Start on the iPhone`() {
        let idle = WatchIdle(workoutsAllowed: true)

        #expect(idle.title == "Start on iPhone")
        #expect(idle.message == "Pick a Workout on your iPhone and tap Start.")
    }

    /// Without workout permission the iPhone never opens the Watch at Start, so "Start on iPhone" would mislead.
    @Test func `Without workouts allowed, the idle Watch sends the owner to Temper's Settings on the iPhone`() {
        let idle = WatchIdle(workoutsAllowed: false)

        #expect(idle.title == "Turn on Apple Health in Temper’s Settings on iPhone")
        #expect(idle.message == nil)
    }
}
