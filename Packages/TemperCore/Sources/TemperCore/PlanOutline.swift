extension Plan {
    /// One line per Block, for the owner to check before Start, such as "Prepare 0:10" or
    /// "10 Rounds · Work until Done · Rest 1:00".
    public nonisolated var outline: [String] {
        blocks.map { block in
            switch block {
            case .phase(let planned):
                return planned.outline
            case .rounds(let count, let phases):
                let rounds =
                    switch count {
                    case .times(1): "1 Round"
                    case .times(let times): "\(times) Rounds"
                    case .untilStop: "Rounds until Stop"
                    }
                return ([rounds] + phases.map(\.outline)).joined(separator: " · ")
            }
        }
    }
}

extension PlannedPhase {
    /// The Phase's name and length, as "Rest 1:00", "Work until Done" or "Work 10:00, then until Done".
    fileprivate nonisolated var outline: String {
        switch length {
        case .set(let duration): "\(kind.name) \(duration.shortClockText(rounding: .up))"
        case .open: "\(kind.name) until Done"
        case .runsPast(let duration): "\(kind.name) \(duration.shortClockText(rounding: .up)), then until Done"
        }
    }
}
