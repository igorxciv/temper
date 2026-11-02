// PROTOTYPE, throw away. Final round: the chosen setup and running screens in the Ink design
// system. Earlier rounds are in this branch's history at d6cee05, 6c6edda, b8542a3, 9fc9369,
// 31084cb, 11379f3 and 8617a1c.
import Foundation
import Observation

enum Field: String, CaseIterable, Identifiable {
    case prepare, rounds, work, rest, cooldown
    var id: String { rawValue }

    var title: String {
        switch self {
        case .prepare: "Prepare"
        case .rounds: "Rounds"
        case .work: "Work"
        case .rest: "Rest"
        case .cooldown: "Cooldown"
        }
    }

    var keyPath: WritableKeyPath<Values, Int> {
        switch self {
        case .prepare: \.prepare
        case .rounds: \.rounds
        case .work: \.work
        case .rest: \.rest
        case .cooldown: \.cooldown
        }
    }

    /// Every time value shares one range in 5-second steps. Only Work can't be zero,
    /// because a Round needs a Work. Zero on any other Phase means the Phase is skipped.
    var options: [Int] {
        switch self {
        case .rounds: Array(1...99)
        case .work: Array(stride(from: 5, through: 1800, by: 5))
        default: Array(stride(from: 0, through: 1800, by: 5))
        }
    }

    func text(_ value: Int) -> String {
        if self == .rounds { return "\(value)" }
        return value == 0 ? "Off" : clock(value)
    }

    func clamped(_ value: Int) -> Int {
        min(max(value, options.first ?? value), options.last ?? value)
    }
}

func clock(_ seconds: Int) -> String {
    String(format: "%02d:%02d", seconds / 60, seconds % 60)
}

struct Values {
    var prepare = 10
    var rounds = 8
    var work = 40
    var rest = 20
    var cooldown = 60

    var phases: [PhaseItem] {
        var list: [PhaseItem] = []
        if prepare > 0 { list.append(PhaseItem(kind: .prepare, seconds: prepare, round: nil)) }
        for round in 1...rounds {
            list.append(PhaseItem(kind: .work, seconds: work, round: round))
            if round < rounds, rest > 0 {
                list.append(PhaseItem(kind: .rest, seconds: rest, round: round))
            }
        }
        if cooldown > 0 { list.append(PhaseItem(kind: .cooldown, seconds: cooldown, round: nil)) }
        return list
    }

    var total: Int { phases.reduce(0) { $0 + $1.seconds } }
}

enum PhaseKind: String {
    case prepare = "Prepare"
    case work = "Work"
    case rest = "Rest"
    case cooldown = "Cooldown"
}

struct PhaseItem {
    let kind: PhaseKind
    let seconds: Int
    let round: Int?
}

/// A stand-in for the real engine: no audio, no background running, no accuracy claims.
@Observable
final class Runner {
    let phases: [PhaseItem]
    let rounds: Int
    private(set) var index = 0
    private(set) var remaining: Double
    private(set) var isPaused = false
    private(set) var isDone = false
    private var phaseEnd: ContinuousClock.Instant
    private var loop: Task<Void, Never>?

    init(values: Values) {
        let list = values.phases
        phases = list
        rounds = values.rounds
        remaining = Double(list[0].seconds)
        phaseEnd = .now + .seconds(list[0].seconds)
        loop = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(50))
                self?.tick()
            }
        }
    }

    var phase: PhaseItem { phases[index] }
    var next: PhaseItem? { index + 1 < phases.count ? phases[index + 1] : nil }
    var timeText: String { clock(Int(remaining.rounded(.up))) }
    var phaseProgress: Double { 1 - remaining / Double(phase.seconds) }

    func togglePause() {
        isPaused.toggle()
        if !isPaused { phaseEnd = .now + .milliseconds(Int(remaining * 1000)) }
    }

    func cancel() { loop?.cancel() }

    /// Probe-bar shortcut for reaching every Phase quickly. Skipping is not a v1 feature.
    func skip() { advance() }

    /// Launch-argument shortcut to the complete screen.
    func finish() {
        isDone = true
        loop?.cancel()
    }

    func jump(to kind: PhaseKind, remaining seconds: Int?) {
        if let found = phases.firstIndex(where: { $0.kind == kind && ($0.round ?? 0) == 3 })
            ?? phases.firstIndex(where: { $0.kind == kind })
        {
            index = found
        }
        remaining = Double(seconds ?? phase.seconds)
        phaseEnd = .now + .milliseconds(Int(remaining * 1000))
    }

    private func tick() {
        guard !isPaused, !isDone else { return }
        remaining = max(0, ContinuousClock.now.duration(to: phaseEnd) / .milliseconds(1) / 1000)
        if remaining <= 0 { advance() }
    }

    private func advance() {
        guard index + 1 < phases.count else {
            isDone = true
            loop?.cancel()
            return
        }
        index += 1
        remaining = Double(phase.seconds)
        phaseEnd = .now + .seconds(phase.seconds)
    }
}

enum Route: Hashable { case settings }

/// How the running screen spends its width. Digits are bound by the width, so these are the only
/// way to win size back without changing the `00:00` format.
enum TimeStyle: String, CaseIterable {
    case current, thin, edge

    var ringWidth: CGFloat {
        switch self {
        case .current: 20
        case .thin: 10
        case .edge: 6
        }
    }
    var digitPadding: CGFloat {
        switch self {
        case .current: 24
        case .thin: 12
        case .edge: 6
        }
    }
    var ringPadding: CGFloat {
        switch self {
        case .current: 10
        case .thin: 5
        case .edge: 3
        }
    }
    var screenPadding: CGFloat {
        switch self {
        case .current: 16
        case .thin: 12
        case .edge: 6
        }
    }
}

@Observable
final class ProbeState {
    /// Set from the system's Increase Contrast setting. The probe bar can force it for comparing.
    var systemIncreasedContrast = false
    var forceIncreasedContrast = UserDefaults.standard.bool(forKey: "ic")
    var theme: Theme { systemIncreasedContrast || forceIncreasedContrast ? .inkIncreased : .ink }
    var timeStyle =
        TimeStyle(rawValue: UserDefaults.standard.string(forKey: "timeStyle") ?? "") ?? .current
    /// The setup words' opacity at normal contrast. Increase Contrast always uses 0.6, which clears 3:1.
    var labelStrength =
        UserDefaults.standard.object(forKey: "label") == nil
        ? 0.32 : UserDefaults.standard.double(forKey: "label")
    var labelOpacity: Double { theme == .inkIncreased ? 0.6 : labelStrength }
    var values = Values()
    var runner: Runner?
    var path: [Route] = []
    var dip = true
    var barVisible = true
    let noBar = UserDefaults.standard.bool(forKey: "noBar")
    var editing: Field?
    var confirmStop = false

    init() {
        let args = UserDefaults.standard
        if args.object(forKey: "rest") != nil { values.rest = args.integer(forKey: "rest") }
        if args.integer(forKey: "rounds") > 0 {
            values.rounds = Field.rounds.clamped(args.integer(forKey: "rounds"))
        }
        if args.string(forKey: "screen") == "complete" {
            start()
            runner?.finish()
        }
        editing = Field(rawValue: args.string(forKey: "edit") ?? "")
        confirmStop = args.bool(forKey: "confirmStop")
        barVisible = !args.bool(forKey: "hideBar")
        if args.string(forKey: "screen") == "settings" { path = [.settings] }
        if args.string(forKey: "screen") == "running" {
            start()
            if let raw = args.string(forKey: "phase"), let kind = PhaseKind(rawValue: raw) {
                let time = args.object(forKey: "time") == nil ? nil : args.integer(forKey: "time")
                runner?.jump(to: kind, remaining: time)
            }
            if args.bool(forKey: "paused") { runner?.togglePause() }
        }
    }

    func start() { runner = Runner(values: values) }

    func stop() {
        runner?.cancel()
        runner = nil
        confirmStop = false
    }
}
