import Foundation
import Testing

@testable import TemperCore

struct WorkoutHeartRateTests {
    /// Boundaries at 132, 144, 156 and 168 bpm.
    private let zones: Zones = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Warsaw")!
        return Zones(
            dateOfBirth: DateComponents(year: 1986, month: 3, day: 1), restingHeartRate: 60,
            start: calendar.date(from: DateComponents(year: 2026, month: 3, day: 2, hour: 12))!, calendar: calendar)!
    }()

    /// Heart-rate read denied looks the same: no reading ever arrives.
    @Test func `Until the first reading, the slot shows -- bpm with no Zone`() {
        let heartRate = WorkoutHeartRate(zones: zones)

        #expect(heartRate.bpmText == "--")
        #expect(heartRate.zone == nil)
        #expect(heartRate.spokenText == "Heart rate not available")
    }

    @Test func `Each reading shows its bpm and is placed in its Zone as it arrives`() {
        var heartRate = WorkoutHeartRate(zones: zones)

        heartRate.record(latest: 150, average: 120, maximum: 150)
        #expect(heartRate.bpmText == "150")
        #expect(heartRate.zone == 3)
        #expect(heartRate.spokenText == "Heart rate 150 beats per minute, Zone 3")

        heartRate.record(latest: 170, average: 130, maximum: 170)
        #expect(heartRate.zone == 5)

        heartRate.record(latest: 131, average: 130, maximum: 170)
        #expect(heartRate.zone == 1)
    }

    @Test func `Without Zones the slot shows the bpm alone`() {
        var heartRate = WorkoutHeartRate(zones: nil)

        heartRate.record(latest: 150, average: 120, maximum: 150)

        #expect(heartRate.bpmText == "150")
        #expect(heartRate.zone == nil)
        #expect(heartRate.spokenText == "Heart rate 150 beats per minute")
    }

    /// The bpm shown is rounded, but the Zone comes from the exact reading.
    @Test func `The bpm shows rounded, and the Zone uses the exact reading`() {
        var heartRate = WorkoutHeartRate(zones: zones)

        heartRate.record(latest: 143.6, average: 120, maximum: 143.6)

        #expect(heartRate.bpmText == "144")
        #expect(heartRate.zone == 2)
    }

    @Test func `The complete screen's line shows the rounded average and max`() {
        var heartRate = WorkoutHeartRate(zones: nil)

        heartRate.record(latest: 140, average: 127.4, maximum: 171.5)

        #expect(heartRate.summary?.averageText == "127")
        #expect(heartRate.summary?.maximumText == "172")
        #expect(heartRate.summary?.spokenText == "Average heart rate 127, max 172 beats per minute")
    }

    @Test func `A Workout with no samples has no line on the complete screen`() {
        #expect(WorkoutHeartRate(zones: zones).summary == nil)
    }
}
