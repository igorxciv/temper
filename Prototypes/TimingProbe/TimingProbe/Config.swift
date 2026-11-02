// PROTOTYPE, throw away. What a run is made of.
import Foundation

struct ProbePhase: Sendable {
    let name: String
    let seconds: Int
}

enum Preset: String, CaseIterable, Identifiable, Sendable {
    case smoke = "Smoke (2 min)"
    case standard = "Standard (14 min)"
    case gaps = "Silent gaps 1-60 min (1 h 51)"
    case drift = "Drift (1 h)"

    var id: String { rawValue }

    var phases: [ProbePhase] {
        switch self {
        case .smoke: Self.workout(prepare: 5, rounds: 3, work: 20, rest: 10, cooldown: 30)
        case .standard: Self.workout(prepare: 10, rounds: 9, work: 60, rest: 30, cooldown: 60)
        case .drift: Self.workout(prepare: 10, rounds: 20, work: 120, rest: 60, cooldown: 120)
        case .gaps:
            [
                ProbePhase(name: "Prepare", seconds: 10),
                ProbePhase(name: "Work", seconds: 60),
                ProbePhase(name: "Rest", seconds: 300),
                ProbePhase(name: "Work", seconds: 900),
                ProbePhase(name: "Rest", seconds: 1800),
                ProbePhase(name: "Work", seconds: 3600),
            ]
        }
    }

    private static func workout(prepare: Int, rounds: Int, work: Int, rest: Int, cooldown: Int)
        -> [ProbePhase]
    {
        var phases = [ProbePhase(name: "Prepare", seconds: prepare)]
        for round in 1...rounds {
            phases.append(ProbePhase(name: "Work", seconds: work))
            if round < rounds { phases.append(ProbePhase(name: "Rest", seconds: rest)) }
        }
        phases.append(ProbePhase(name: "Cooldown", seconds: cooldown))
        return phases
    }
}

enum KeepAlive: String, CaseIterable, Identifiable, Sendable {
    case zeros = "Engine rendering zeros"
    case quiet = "Very quiet signal"
    case sessionOnly = "Engine stopped, session active"
    var id: String { rawValue }
}

enum DipMode: String, CaseIterable, Identifiable, Sendable {
    case off = "Off (mix)"
    case sessionCycle = "A: session cycle"
    case optionToggle = "B: change options while active"
    case synthSession = "C: separate synthesizer session"
    var id: String { rawValue }

    var lead: Duration {
        switch self {
        case .off, .optionToggle: .seconds(1)
        case .sessionCycle: .milliseconds(1500)
        case .synthSession: .zero
        }
    }
}

struct RunConfig: Sendable {
    var preset = Preset.smoke
    var keepAlive = KeepAlive.zeros
    var dip = DipMode.off
    var compensateLatency = false
    var heartbeat = false
    var note = ""
}
