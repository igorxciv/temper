import Foundation

/// What a tap on the Watch asks the iPhone engine to do: the capsule's Done, Pause or Resume, or the secondary page's
/// Pause, Resume or Stop.
public nonisolated enum WatchCommand: String, Codable, Hashable, Sendable {
    case done
    case pause
    case resume
    case stop
}

/// What the Watch sends the iPhone over the mirrored workout session, encoded as JSON.
///
/// There are no acknowledgements. The update a tap causes shows it worked, and `refused` shows it came too late.
public nonisolated enum MessageFromWatch: Codable, Hashable, Sendable {
    /// A tap, dated on the Watch's clock when the owner made it, so the time it takes to reach the iPhone doesn't
    /// count.
    case tap(WatchCommand, at: Date)

    /// Decodes a message from the JSON `json()` made.
    public init(json: Data) throws {
        self = try JSONDecoder().decode(Self.self, from: json)
    }

    /// The message as JSON, for `sendToRemoteWorkoutSession(data:)`.
    public func json() throws -> Data {
        try JSONEncoder().encode(self)
    }
}

/// Where a tap the Watch dated on its own clock lands on the iPhone engine's clock.
///
/// The Watch and iPhone clocks agree to within milliseconds, so the tap's age on arrival places it that far back on
/// the engine clock, and a hand-ended Work's time leaves out the trip. A tap that took too long is refused rather
/// than placed, because the owner has moved on. The engine then clamps the placed instant as it does every tap, so it
/// never lands before what the engine already applied or after now.
public nonisolated enum WatchTap {
    /// The oldest a tap can be when it arrives and still be placed.
    public static var limit: Duration { .seconds(2) }

    /// The engine instant of a tap the Watch dated `tap`, with `arrival` read as it reached the iPhone, or `nil` for
    /// a tap more than ``limit`` old on arrival.
    public static func instant<Instant>(of tap: Date, arrival: ClockAnchor<Instant>) -> Instant? {
        guard arrival.date.timeIntervalSince(tap) <= limit / .seconds(1) else { return nil }
        return arrival.instant(of: tap)
    }
}
