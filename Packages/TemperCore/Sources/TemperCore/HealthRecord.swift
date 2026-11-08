import Foundation

/// What Temper saves to Apple Health as the Health workout of one ended Workout.
///
/// It's built from the Workout record, so it holds wall-clock dates rather than engine instants, and it's `Codable`
/// so a pending save can be stored and tried again after the record and its clock are gone. The Health workout spans
/// `start` to `end`, of `activityType`. It gets a `pause` event at each Pause's start and a `resume` event at its
/// end, and one activity per entry in `activities`, of the same activity type, with `TemperPhase` and, when there's
/// a Round, `TemperRound` metadata. Its only workout metadata is `syncIdentifier` and `syncVersion`. A retry saves
/// `withSyncVersion(_:)` of the next attempt number.
public nonisolated struct HealthRecord: Codable, Hashable, Sendable {
    /// The kind of exercise Health files the Health workout under. The raw values name the HealthKit
    /// `HKWorkoutActivityType` cases they stand for, and a pending save stores them.
    public enum ActivityType: String, Codable, Hashable, Sendable {
        case highIntensityIntervalTraining
        case other
        case traditionalStrengthTraining

        /// Intervals is High Intensity Interval Training, Stopwatch is Other, and Open Rounds is Traditional
        /// Strength Training.
        public init(_ workoutType: WorkoutType) {
            switch workoutType {
            case .intervals: self = .highIntensityIntervalTraining
            case .stopwatch: self = .other
            case .openRounds: self = .traditionalStrengthTraining
            }
        }
    }

    /// A Pause, from its tap to its Resume, saved as a `pause` event at its start and a `resume` event at its end,
    /// so Health leaves it out of the duration of the Health workout and of any activity it falls in.
    public struct Pause: Codable, Hashable, Sendable {
        public let start: Date
        public let end: Date

        public init(start: Date, end: Date) {
            self.start = start
            self.end = end
        }
    }

    /// A Phase that ran, saved as an activity of the Health workout's activity type, from its start to its end. A
    /// Pause inside it stays inside it, and Health leaves the Pause out of its duration.
    public struct Activity: Codable, Hashable, Sendable {
        /// The metadata key whose value is ``phaseMetadataValue``.
        public static let phaseMetadataKey = "TemperPhase"
        /// The metadata key whose value is ``round``, left out when there's no Round.
        public static let roundMetadataKey = "TemperRound"

        public let phase: Phase.Kind
        /// The Round it belongs to, or `nil` for Prepare, Cooldown and a Stopwatch's Work.
        public let round: Int?
        public let start: Date
        public let end: Date

        public init(phase: Phase.Kind, round: Int?, start: Date, end: Date) {
            self.phase = phase
            self.round = round
            self.start = start
            self.end = end
        }

        /// The Phase as `prepare`, `work`, `rest` or `cooldown`.
        public var phaseMetadataValue: String {
            phase.rawValue
        }
    }

    /// The least active time a Workout needs to be saved.
    public static let minimumActiveTime = Duration.seconds(60)

    public let activityType: ActivityType
    /// The Start, which is also the start of the Prepare if there is one.
    public let start: Date
    /// The finish, or the Stop.
    public let end: Date
    /// Each Pause, in order. A Pause still on at Stop ends at the Stop.
    public let pauses: [Pause]
    /// Each Phase that ran, in order. A Phase cut short by Stop ends at the Stop. A Phase that would have started at
    /// the very moment of the Stop never ran, so it isn't here.
    public let activities: [Activity]
    /// The Workout's UUID, made at Start.
    public let workoutID: UUID
    /// The attempt this record is for, starting at 1, saved as `HKMetadataKeySyncVersion`. A higher version replaces
    /// an earlier save with the same sync identifier, so whichever attempt lands last leaves one Health workout.
    public private(set) var syncVersion: Int

    /// The Workout's UUID as a string, saved as `HKMetadataKeySyncIdentifier`.
    public var syncIdentifier: String {
        workoutID.uuidString
    }

    /// The Health workout for `record`, or `nil` if it ran for less than ``minimumActiveTime`` of active time and so
    /// isn't saved.
    ///
    /// The engine's instants become dates through one pair read together at the end: `instant` on the engine clock
    /// and `date` on the wall clock. The engine's clock keeps counting while the iPhone sleeps, so the pair places
    /// every instant of the Workout.
    public init?<Instant>(
        _ record: WorkoutRecord<Instant>,
        of workoutType: WorkoutType,
        workoutID: UUID,
        attempt: Int,
        at instant: Instant,
        date: Date
    ) where Instant.Duration == Duration {
        precondition(attempt >= 1, "Attempts are numbered from 1")
        guard record.activeTime >= Self.minimumActiveTime else { return nil }
        func dateOf(_ other: Instant) -> Date {
            date.addingTimeInterval(instant.duration(to: other) / .seconds(1))
        }
        activityType = ActivityType(workoutType)
        start = dateOf(record.start)
        end = dateOf(record.end)
        pauses = record.pauses.map { Pause(start: dateOf($0.lowerBound), end: dateOf($0.upperBound)) }
        activities = record.phases.filter { $0.start < $0.end }.map { phase in
            Activity(phase: phase.kind, round: phase.round, start: dateOf(phase.start), end: dateOf(phase.end))
        }
        self.workoutID = workoutID
        syncVersion = attempt
    }

    /// The same record for another attempt at saving it, which only changes its sync version.
    public func withSyncVersion(_ syncVersion: Int) -> HealthRecord {
        precondition(syncVersion >= 1, "Attempts are numbered from 1")
        var record = self
        record.syncVersion = syncVersion
        return record
    }
}
