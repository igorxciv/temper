import Foundation
import Testing

@testable import TemperCore

struct ZonesTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Warsaw")!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    /// Someone who turned 40 on the day before Start has a maximum of 208 − 0.7 × 40 = 180, so with a resting rate of
    /// 60 the reserve is 120, and the boundaries sit at 132, 144, 156 and 168.
    private var fortyYearOld: Zones {
        Zones(
            dateOfBirth: DateComponents(year: 1986, month: 3, day: 1), restingHeartRate: 60, start: date(2026, 3, 2),
            calendar: calendar)!
    }

    @Test(arguments: [
        (100.0, 1), (131.9, 1), (132, 2), (143.9, 2), (144, 3), (155.9, 3), (156, 4), (167.9, 4), (168, 5),
        (179, 5),
    ])
    func `Each Zone starts at 60, 70, 80 and 90% of the heart-rate reserve`(bpm: Double, zone: Int) {
        #expect(fortyYearOld.zone(of: bpm) == zone)
    }

    /// Born on 15 June 1990 with a resting rate of 60, Zone 2 starts at 133.68 bpm from the 36th birthday (a maximum of
    /// 182.8), and at 134.1 bpm the day before (35, a maximum of 183.5).
    @Test func `The age counts in whole years on the day of Start, turning over on the birthday`() {
        let birth = DateComponents(year: 1990, month: 6, day: 15)
        let birthday = Zones(
            dateOfBirth: birth, restingHeartRate: 60, start: date(2026, 6, 15, 0, 1), calendar: calendar)
        let dayBefore = Zones(
            dateOfBirth: birth, restingHeartRate: 60, start: date(2026, 6, 14, 23, 59), calendar: calendar)

        #expect(birthday?.zone(of: 133.68) == 2)
        #expect(birthday?.zone(of: 133.6) == 1)
        #expect(dayBefore?.zone(of: 134) == 1)
        #expect(dayBefore?.zone(of: 134.1) == 2)
    }

    @Test func `A bpm under the resting rate is in Zone 1, and one over the maximum in Zone 5`() {
        #expect(fortyYearOld.zone(of: 45) == 1)
        #expect(fortyYearOld.zone(of: 0) == 1)
        #expect(fortyYearOld.zone(of: 195) == 5)
    }
}
