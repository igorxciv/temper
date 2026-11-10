/// The heart rate the Watch shows during one Workout: the latest reading in the running screen's slot, placed in its
/// Zone, and the average and max on the complete screen. Heart rate never shows on the iPhone or the Live Activity.
///
/// A denied heart-rate read and a reading that hasn't arrived yet look the same: nothing is recorded.
public nonisolated struct WorkoutHeartRate: Equatable, Sendable {
    /// The average and max heart rate of a Workout with at least one sample.
    public struct Summary: Equatable, Sendable {
        let average: Double
        let maximum: Double

        public var averageText: String { roundedBPM(average) }
        public var maximumText: String { roundedBPM(maximum) }

        public var spokenText: String {
            "Average heart rate \(averageText), max \(maximumText) beats per minute"
        }
    }

    /// `nil` without a date of birth or a resting rate, which hides the Zone meter for the whole Workout. Health reads
    /// them when the session starts, and the Zones are set once then and kept until Stop.
    public var zones: Zones?
    private var latest: Double?
    public private(set) var summary: Summary?

    public init(zones: Zones?) {
        self.zones = zones
    }

    /// Records the session's heart rate so far, as each reading arrives. The Zone isn't smoothed: it follows `latest`.
    public mutating func record(latest: Double, average: Double, maximum: Double) {
        self.latest = latest
        summary = Summary(average: average, maximum: maximum)
    }

    /// The latest bpm, rounded, or "--" until the first reading. The slot adds "bpm" after it.
    public var bpmText: String {
        latest.map(roundedBPM) ?? "--"
    }

    /// The Zone of the latest reading, or `nil`, which hides the meter, until the first reading or without Zones.
    public var zone: Int? {
        guard let latest, let zones else { return nil }
        return zones.zone(of: latest)
    }

    public var spokenText: String {
        guard latest != nil else { return "Heart rate not available" }
        let bpm = "Heart rate \(bpmText) beats per minute"
        return zone.map { "\(bpm), Zone \($0)" } ?? bpm
    }
}

private nonisolated func roundedBPM(_ bpm: Double) -> String {
    String(Int(bpm.rounded()))
}
