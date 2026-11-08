// PROBE, throwaway. What crosses the mirrored session's data channel, in both directions.

import Foundation

/// One message over `sendToRemoteWorkoutSession`. JSON, well under the 100 KB per 10 s limit.
nonisolated enum Wire: Codable, Sendable {
    /// iPhone → Watch, as soon as the mirrored session arrives: how this run records.
    case plan(Plan)
    /// iPhone → Watch: a stand-in Phase started, on the iPhone's clock.
    case phase(Phase)
    /// iPhone → Watch: Pause and Resume, stamped with the iPhone's clock.
    case pause(at: Date)
    case resume(at: Date)
    /// iPhone → Watch: Stop. Carries the iPhone's record, which the Watch uses in the `record` activity mode.
    case stop(Record)
    /// Watch → iPhone, every 5 s: the latest heart rate and how many heart-rate updates the builder has sent.
    case status(heartRate: Double?, updates: Int)
    /// Watch → iPhone: the Watch saved its workout. The iPhone uses this for its own save in run B.
    case saved(start: Date, end: Date)
    /// Watch → iPhone: one line of the Watch's log, so a single file on the iPhone holds both sides.
    case log(line: String, at: Date)

    func encoded() -> Data {
        // Every case encodes, so the empty fallback never goes out.
        (try? JSONEncoder().encode(self)) ?? Data()
    }

    static func decode(_ data: Data) -> Wire? {
        try? JSONDecoder().decode(Wire.self, from: data)
    }
}

nonisolated enum ActivityMode: String, Codable, Sendable {
    /// No activities.
    case none
    /// `session.beginNewActivity` at each Phase message. Phases after the first are dated 1.5 s early, the way a
    /// Phase start that reached the Watch late would be.
    case live
    /// `shouldCollectWorkoutEvents = false`, then `builder.addWorkoutActivity` and `addWorkoutEvents` at Stop, from
    /// the iPhone's record.
    case record
}

nonisolated struct Plan: Codable, Sendable {
    var run: String
    /// The Workout's Start, on the iPhone's clock. The Watch starts its session and collection here.
    var workoutStart: Date
    var activities: ActivityMode
    var syncIdentifier: String?
    var syncVersion: Int?
}

nonisolated struct Phase: Codable, Sendable {
    var index: Int
    var kind: String
    var round: Int
    var start: Date
}

nonisolated struct Record: Codable, Sendable {
    struct Span: Codable, Sendable {
        var start: Date
        var end: Date
    }

    struct Activity: Codable, Sendable {
        var kind: String
        var round: Int
        var start: Date
        var end: Date
    }

    var end: Date
    var activities: [Activity]
    var pauses: [Span]
}

/// The stand-in Workout both runs use: Work 20 s, Rest 10 s, repeating.
nonisolated enum StandIn {
    static let work: TimeInterval = 20
    static let rest: TimeInterval = 10

    /// The Phase running `elapsed` seconds after the Workout's Start.
    static func phase(at elapsed: TimeInterval, workoutStart: Date) -> Phase {
        let cycle = work + rest
        let round = Int((elapsed / cycle).rounded(.down))
        let into = elapsed - Double(round) * cycle
        let isWork = into < work
        let start = workoutStart + Double(round) * cycle + (isWork ? 0 : work)
        return Phase(
            index: round * 2 + (isWork ? 0 : 1), kind: isWork ? "work" : "rest", round: round + 1, start: start)
    }

    static func end(of phase: Phase) -> Date {
        phase.start + (phase.kind == "work" ? work : rest)
    }
}

nonisolated func secs(_ seconds: TimeInterval) -> String {
    String(format: "%.2f s", seconds)
}

/// Carries a HealthKit object across an isolation boundary. HealthKit's callbacks hand over non-Sendable sessions,
/// and the probe touches them only on the main actor afterwards.
nonisolated struct Handed<Value>: @unchecked Sendable {
    let value: Value
}
