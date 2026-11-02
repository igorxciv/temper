// PROTOTYPE, throw away. Three setup and three running variants, switchable from a floating bar.
import Foundation
import Observation

/// Proposed v1 ranges. The owner decides these on the ticket.
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

    /// Every value the steppers land on. Times are in seconds.
    var options: [Int] {
        let steps =
            Array(stride(from: 5, through: 60, by: 5))
            + Array(stride(from: 75, through: 300, by: 15))
        switch self {
        case .prepare: return steps
        case .rounds: return Array(1...99)
        case .work: return steps + Array(stride(from: 360, through: 1800, by: 60))
        case .rest: return steps + Array(stride(from: 360, through: 600, by: 60))
        case .cooldown: return [0] + steps + Array(stride(from: 360, through: 1800, by: 60))
        }
    }

    var presets: [Int] {
        switch self {
        case .prepare: [5, 10, 15, 30]
        case .rounds: [3, 5, 8, 10, 12, 20]
        case .work: [20, 30, 40, 45, 60, 90, 120, 180]
        case .rest: [10, 15, 20, 30, 45, 60, 90, 120]
        case .cooldown: [0, 30, 60, 120, 180, 300]
        }
    }

    func text(_ value: Int) -> String {
        switch self {
        case .rounds: "\(value)"
        case .cooldown where value == 0: "Off"
        default: clock(value)
        }
    }

    func stepped(_ value: Int, up: Bool) -> Int {
        if up {
            options.first { $0 > value } ?? value
        } else {
            options.last { $0 < value } ?? value
        }
    }

    func clamped(_ value: Int) -> Int {
        if self == .cooldown, value == 0 { return 0 }
        let lowest = options.first { $0 > 0 } ?? 1
        return min(max(value, lowest), options.last ?? value)
    }
}

func clock(_ seconds: Int) -> String {
    String(format: "%d:%02d", seconds / 60, seconds % 60)
}

struct Values {
    var prepare = 10
    var rounds = 8
    var work = 40
    var rest = 20
    var cooldown = 60

    var phases: [PhaseItem] {
        var list = [PhaseItem(kind: .prepare, seconds: prepare, round: nil)]
        for round in 1...rounds {
            list.append(PhaseItem(kind: .work, seconds: work, round: round))
            if round < rounds { list.append(PhaseItem(kind: .rest, seconds: rest, round: round)) }
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

enum Letter: String, CaseIterable {
    case a = "A"
    case b = "B"
    case c = "C"
}

@Observable
final class ProbeState {
    var setup: Letter
    var running: Letter
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
        setup = Letter(rawValue: args.string(forKey: "setup") ?? "") ?? .a
        running = Letter(rawValue: args.string(forKey: "running") ?? "") ?? .a
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
