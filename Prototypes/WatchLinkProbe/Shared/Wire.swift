// PROBE, throwaway. What crosses the mirrored session's data channel, in both directions.

import Foundation

/// One message over `sendToRemoteWorkoutSession`. JSON, well under the 100 KB per 10 s limit.
nonisolated enum Wire: Codable, Sendable {
    /// Watch → iPhone, right after mirroring starts: when each launch step ran, on the Watch's clock.
    case hello(steps: [Step])
    /// Watch → iPhone: a tap on the Watch's capsule, stamped with the Watch's clock.
    case tap(id: Int, at: Date)
    /// iPhone → Watch: the tap arrived and its beep was scheduled, stamped with the iPhone's clock.
    case tapAck(id: Int, at: Date)
    /// Either way, every 5 s. The other side answers at once with `pong`. The Watch adds its latest heart rate.
    case ping(id: Int, at: Date, heartRate: Double?)
    case pong(id: Int, pingAt: Date, at: Date)
    /// iPhone → Watch: when a 1:00 stand-in Phase started, on the iPhone's clock. The Watch draws its countdown
    /// from this date with its own clock, as the real app would.
    case phase(startedAt: Date)
    /// Watch → iPhone: one line of the Watch's log, so a single file on the iPhone holds both sides.
    case log(line: String, at: Date)

    struct Step: Codable, Sendable, Identifiable {
        var name: String
        var at: Date
        var id: String { name + at.description }
    }

    func encoded() -> Data {
        // Every case encodes, so the empty fallback never goes out.
        (try? JSONEncoder().encode(self)) ?? Data()
    }

    static func decode(_ data: Data) -> Wire? {
        try? JSONDecoder().decode(Wire.self, from: data)
    }
}

/// The length of the stand-in Phase both screens count down.
nonisolated let phaseLength: TimeInterval = 60

/// What one ping and its pong say about the other device's clock.
nonisolated struct ClockSample: Sendable {
    var roundTrip: TimeInterval
    /// The other device's clock minus this one's, taking both legs as equally long.
    var theirsAhead: TimeInterval

    init(pingAt: Date, theirReplyAt: Date, receivedAt: Date) {
        roundTrip = receivedAt.timeIntervalSince(pingAt)
        theirsAhead = theirReplyAt.timeIntervalSince(pingAt) - roundTrip / 2
    }
}

/// Running counts for one side of the link.
nonisolated struct LinkStats: Sendable {
    var pingsSent = 0
    var sendFailures = 0
    var pongs = 0
    var pingsReceived = 0
    var lastRoundTrip: TimeInterval?
    var maxRoundTrip: TimeInterval = 0
    var roundTrips: [TimeInterval] = []
    /// The sample with the shortest round trip, the best guess at the clock offset.
    var best: ClockSample?
    var lastHeard: Date?
    var connectedSince: Date?

    mutating func record(_ sample: ClockSample) {
        pongs += 1
        lastRoundTrip = sample.roundTrip
        maxRoundTrip = max(maxRoundTrip, sample.roundTrip)
        roundTrips.append(sample.roundTrip)
        if sample.roundTrip <= best?.roundTrip ?? .infinity { best = sample }
    }

    var medianRoundTrip: TimeInterval? {
        guard !roundTrips.isEmpty else { return nil }
        return roundTrips.sorted()[roundTrips.count / 2]
    }

    var summary: String {
        var parts = [
            "pings \(pingsSent) sent, \(pongs) answered, \(sendFailures) send errors, \(pingsReceived) received"
        ]
        if let median = medianRoundTrip {
            parts.append("round trip median \(ms(median)), max \(ms(maxRoundTrip))")
        }
        if let best {
            parts.append("their clock ahead by \(ms(best.theirsAhead)) (±\(ms(best.roundTrip / 2)))")
        }
        if let connectedSince {
            parts.append("connected \(Int(Date.now.timeIntervalSince(connectedSince))) s")
        }
        return parts.joined(separator: "; ")
    }
}

nonisolated func ms(_ seconds: TimeInterval) -> String {
    "\(Int((seconds * 1000).rounded())) ms"
}

nonisolated func secs(_ seconds: TimeInterval) -> String {
    String(format: "%.2f s", seconds)
}

/// Seconds left in the stand-in Phase that started at `start`, repeating every `phaseLength`.
nonisolated func phaseRemaining(from start: Date, at now: Date) -> TimeInterval {
    let elapsed = now.timeIntervalSince(start)
    let into = elapsed - (elapsed / phaseLength).rounded(.down) * phaseLength
    return phaseLength - into
}

nonisolated func countdown(_ remaining: TimeInterval) -> String {
    let tenths = Int((remaining * 10).rounded(.down))
    return String(format: "%d:%02d.%d", tenths / 600, (tenths / 10) % 60, tenths % 10)
}

/// Carries a HealthKit object across an isolation boundary. HealthKit's callbacks hand over non-Sendable sessions,
/// and the probe touches them only on the main actor afterwards.
nonisolated struct Handed<Value>: @unchecked Sendable {
    let value: Value
}
