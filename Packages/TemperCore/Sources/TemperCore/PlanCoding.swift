/// A Plan as it's stored, in JSON. Every key is spelled out here rather than synthesized, so renaming a Swift case or
/// property can't change what's stored:
///
/// ```json
/// {
///   "version": 1,
///   "activity": "traditionalStrengthTraining",
///   "warnsBeforeRestEnds": true,
///   "blocks": [
///     {"phase": {"kind": "prepare", "length": "set", "seconds": 10}},
///     {"rounds": {"times": 10, "phases": [
///       {"kind": "work", "length": "open"},
///       {"kind": "rest", "length": "set", "seconds": 60}
///     ]}}
///   ]
/// }
/// ```
///
/// Rounds until Stop say `"untilStop": true` in place of `"times"`. Decoding checks only the shape: a stored Plan
/// still goes through `makeWorkout()` before it runs.
nonisolated extension Plan: Codable {
    /// The version of the stored format. Raise it whenever a change would be misread by a build that reads the
    /// current one. A build reads every version up to its own, and fails on a later one, so it drops a Plan it can't
    /// read rather than running the wrong Workout. A new key that an older build can safely ignore needs no new
    /// version.
    public static let formatVersion = 1

    private enum CodingKeys: String, CodingKey {
        case version, activity, warnsBeforeRestEnds, blocks
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decode(Int.self, forKey: .version)
        guard (1...Self.formatVersion).contains(version) else {
            throw DecodingError.dataCorruptedError(
                forKey: .version, in: container, debugDescription: "A later Plan format, \(version)")
        }
        self.init(
            activity: try container.decode(HealthRecord.ActivityType.self, forKey: .activity),
            blocks: try container.decode([Block].self, forKey: .blocks),
            warnsBeforeRestEnds: try container.decodeIfPresent(Bool.self, forKey: .warnsBeforeRestEnds) ?? false
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.formatVersion, forKey: .version)
        try container.encode(activity, forKey: .activity)
        try container.encode(warnsBeforeRestEnds, forKey: .warnsBeforeRestEnds)
        try container.encode(blocks, forKey: .blocks)
    }
}

nonisolated extension Plan.Block: Codable {
    private enum CodingKeys: String, CodingKey {
        case phase, rounds
    }

    private enum RoundsKeys: String, CodingKey {
        case times, untilStop, phases
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard container.allKeys.count == 1, let key = container.allKeys.first else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "A Block is one phase or one rounds"))
        }
        switch key {
        case .phase:
            self = .phase(try container.decode(PlannedPhase.self, forKey: .phase))
        case .rounds:
            let rounds = try container.nestedContainer(keyedBy: RoundsKeys.self, forKey: .rounds)
            let times = try rounds.decodeIfPresent(Int.self, forKey: .times)
            let untilStop = try rounds.decodeIfPresent(Bool.self, forKey: .untilStop) ?? false
            let count: Count
            switch (times, untilStop) {
            case (let times?, false): count = .times(times)
            case (nil, true): count = .untilStop
            default:
                throw DecodingError.dataCorruptedError(
                    forKey: .times, in: rounds, debugDescription: "Rounds have either times or untilStop")
            }
            self = .rounds(count, try rounds.decode([PlannedPhase].self, forKey: .phases))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .phase(let planned):
            try container.encode(planned, forKey: .phase)
        case .rounds(let count, let phases):
            var rounds = container.nestedContainer(keyedBy: RoundsKeys.self, forKey: .rounds)
            switch count {
            case .times(let times): try rounds.encode(times, forKey: .times)
            case .untilStop: try rounds.encode(true, forKey: .untilStop)
            }
            try rounds.encode(phases, forKey: .phases)
        }
    }
}

nonisolated extension PlannedPhase: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind, length, seconds
    }

    /// The stored names of a Phase's lengths.
    private enum StoredLength: String, Codable {
        case set, open, runsPast
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Phase.Kind.self, forKey: .kind)
        switch try container.decode(StoredLength.self, forKey: .length) {
        case .open:
            self.init(kind: kind, length: .open)
        case .set:
            self.init(kind: kind, length: .set(.seconds(try container.decode(Double.self, forKey: .seconds))))
        case .runsPast:
            self.init(kind: kind, length: .runsPast(.seconds(try container.decode(Double.self, forKey: .seconds))))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        switch length {
        case .open:
            try container.encode(StoredLength.open, forKey: .length)
        case .set(let duration):
            try container.encode(StoredLength.set, forKey: .length)
            try container.encode(duration / .seconds(1), forKey: .seconds)
        case .runsPast(let duration):
            try container.encode(StoredLength.runsPast, forKey: .length)
            try container.encode(duration / .seconds(1), forKey: .seconds)
        }
    }
}
