/// A Plan as the board writes it up: one line per Phase in the order it runs, with each Rounds Block's lines held
/// together under its count, and a note for what the lines alone don't say.
///
/// A Workout Type's board also keeps its Off lines, which its Plan leaves out, so a Prepare can be turned back on
/// where it stands, and names the setup value each line edits.
public nonisolated struct PlanBoard: Equatable, Sendable {
    /// One part of the board.
    public enum Item: Equatable, Sendable {
        case line(Line)
        /// A Rounds Block's lines, bracketed under how many times they run. `value` is what edits the count.
        case rounds(Plan.Block.Count, [Line], value: WorkoutValue?)
    }

    /// One Phase's line.
    public struct Line: Equatable, Sendable {
        /// How long the line's Phase runs.
        public enum Length: Equatable, Sendable {
            case set(Duration)
            /// A Workout Type's Phase at zero, which won't run.
            case off
            /// It ends at Done.
            case open
            /// It counts to this length, then on until Done.
            case runsPast(Duration)
        }

        public let kind: Phase.Kind
        public let length: Length
        /// The setup value that edits it, or `nil` if it can't be edited, as an open Work or a described Plan's line.
        public let value: WorkoutValue?

        public init(kind: Phase.Kind, length: Length, value: WorkoutValue? = nil) {
            self.kind = kind
            self.length = length
            self.value = value
        }

        /// The line's time, as "0:40", "Off", "Open" or, for a length it runs past, "10:00".
        public var time: String {
            switch length {
            case .set(let duration), .runsPast(let duration): duration.shortClockText(rounding: .up)
            case .off: "Off"
            case .open: "Open"
            }
        }

        /// What follows the time, for a length that doesn't end where it says.
        public var caption: String? {
            switch length {
            case .set, .off: nil
            case .open: "until Done"
            case .runsPast: "then until Done"
            }
        }

        /// What VoiceOver reads for the line.
        public var spokenText: String {
            switch length {
            case .set(let duration): "\(kind.name), \(duration.spokenText(rounding: .up))"
            case .off: "\(kind.name), Off"
            case .open: "\(kind.name), open until Done"
            case .runsPast(let duration): "\(kind.name), \(duration.spokenText(rounding: .up)), then until Done"
            }
        }
    }

    public let items: [Item]

    public init(items: [Item]) {
        self.items = items
    }

    /// A Plan's board, for reading only.
    public init(plan: Plan) {
        items = plan.blocks.map { block in
            switch block {
            case .phase(let planned): .line(Line(planned))
            case .rounds(let count, let phases): .rounds(count, phases.map(Line.init), value: nil)
            }
        }
    }

    /// A Workout Type's board, in the shape of its built-in Plan, with its Off lines kept and every line it can edit
    /// naming its value.
    public init(workoutType: WorkoutType, settings: WorkoutSettings) {
        func line(_ value: WorkoutValue) -> Line {
            guard let kind = value.phaseKind else { preconditionFailure("Rounds has no line") }
            let amount = settings[value]
            return Line(kind: kind, length: amount == 0 ? .off : .set(.seconds(amount)), value: value)
        }
        switch workoutType {
        case .intervals:
            items = [
                .line(line(.prepare)),
                .rounds(.times(settings.rounds), [line(.work), line(.rest)], value: .rounds),
                .line(line(.cooldown)),
            ]
        case .stopwatch:
            items = [
                .line(line(.prepare)),
                .line(Line(kind: .work, length: .runsPast(settings.work), value: .work)),
            ]
        case .openRounds:
            let round = [Line(kind: .work, length: .open), line(.rest)]
            // A Cooldown can't follow Rounds until Stop, so its line shows only once Rounds have a number.
            if settings.rounds == WorkoutType.roundsUntilStop {
                items = [.line(line(.prepare)), .rounds(.untilStop, round, value: .rounds)]
            } else {
                items = [
                    .line(line(.prepare)),
                    .rounds(.times(settings.rounds), round, value: .rounds),
                    .line(line(.cooldown)),
                ]
            }
        }
    }

    /// What the lines alone don't say, or `nil` if they say it all: that the last of a set number of Rounds skips its
    /// Rest, that an open Phase waits for Done, that Rounds until Stop repeat until Stop, and, where setup can give
    /// them a number, that a number is what makes room for a Cooldown.
    public var note: String? {
        var sentences: [String] = []
        for case .rounds(let count, let lines, let value) in items {
            let endsOnRest = lines.last(where: { $0.length != .off })?.kind == .rest
            switch count {
            case .times(let times) where times > 1 && endsOnRest:
                sentences.append("The last Round skips Rest.")
            case .untilStop:
                sentences.append("Rounds repeat until you Stop.")
                if value != nil {
                    sentences.append("Set a number of Rounds to add a Cooldown.")
                }
            case .times:
                break
            }
        }
        if allLines.contains(where: { $0.length == .open }) {
            sentences.insert("Tap Done to end each open Work.", at: 0)
        } else if case .runsPast(let duration)? = allLines.first(where: { $0.kind == .work })?.length {
            sentences.insert(
                "Work counts on past \(duration.shortClockText(rounding: .up)) until you tap Done.", at: 0)
        }
        return sentences.isEmpty ? nil : sentences.joined(separator: " ")
    }

    /// Every line, top to bottom.
    public var allLines: [Line] {
        items.flatMap { item -> [Line] in
            switch item {
            case .line(let line): [line]
            case .rounds(_, let lines, _): lines
            }
        }
    }
}

extension PlanBoard.Line {
    fileprivate nonisolated init(_ planned: PlannedPhase) {
        let length: Length =
            switch planned.length {
            case .set(let duration): .set(duration)
            case .open: .open
            case .runsPast(let duration): .runsPast(duration)
            }
        self.init(kind: planned.kind, length: length)
    }
}
