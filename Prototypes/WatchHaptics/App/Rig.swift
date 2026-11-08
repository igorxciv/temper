// PROTOTYPE, throwaway. A stand-in Workout that fires each Cue's haptic on the Watch, under a workout session that
// never saves, so haptics keep playing with the wrist down. The clock is the Watch's own; nothing talks to the iPhone.

import Foundation
import HealthKit
import Observation

enum PhaseKind {
    case prepare, work, rest, cooldown

    var name: String {
        switch self {
        case .prepare: "Prepare"
        case .work: "Work"
        case .rest: "Rest"
        case .cooldown: "Cooldown"
        }
    }

    /// Prepare starts silently, as on the iPhone.
    var cue: CueKind? {
        switch self {
        case .prepare: nil
        case .work: .work
        case .rest: .rest
        case .cooldown: .cooldown
        }
    }
}

struct Phase: Equatable {
    let kind: PhaseKind
    /// In seconds, or `nil` for open Work, which ends at Done.
    let length: TimeInterval?
    let round: Int
}

/// The shape of the stand-in Workout.
enum Plan: Equatable {
    case intervals(work: TimeInterval, rest: TimeInterval, rounds: Int, cooldown: Bool)
    case openRounds(rest: TimeInterval)

    var first: Phase { Phase(kind: .prepare, length: 10, round: 0) }

    var rounds: Int? {
        if case .intervals(_, _, let rounds, _) = self { rounds } else { nil }
    }

    /// Only an Open Rounds Rest says "10 seconds", and only when it's 0:20 or longer.
    var warnsBeforeRestEnds: Bool {
        if case .openRounds = self { true } else { false }
    }

    var activity: HKWorkoutActivityType {
        switch self {
        case .intervals: .highIntensityIntervalTraining
        case .openRounds: .traditionalStrengthTraining
        }
    }

    /// The Phase after `phase`, or `nil` when the Workout finishes.
    func phase(after phase: Phase) -> Phase? {
        switch self {
        case .intervals(let work, let rest, let rounds, let cooldown):
            switch phase.kind {
            case .prepare: Phase(kind: .work, length: work, round: 1)
            case .work where phase.round < rounds: Phase(kind: .rest, length: rest, round: phase.round)
            case .work: cooldown ? Phase(kind: .cooldown, length: 60, round: phase.round) : nil
            case .rest: Phase(kind: .work, length: work, round: phase.round + 1)
            case .cooldown: nil
            }
        case .openRounds(let rest):
            switch phase.kind {
            case .prepare: Phase(kind: .work, length: nil, round: 1)
            case .work: Phase(kind: .rest, length: rest, round: phase.round)
            case .rest, .cooldown: Phase(kind: .work, length: nil, round: phase.round + 1)
            }
        }
    }
}

struct LogEntry: Identifiable {
    let id = UUID()
    let date: Date
    let text: String
}

/// The settings, the stand-in Workout, and the log of every Cue fired.
@Observable
final class Rig {
    var schemeID = Scheme.candidates[0].id
    var custom: [CueKind: Step] = [
        .work: Step(tap: .start, count: 1), .rest: Step(tap: .stop, count: 1),
        .cooldown: Step(tap: .directionDown, count: 1), .complete: Step(tap: .success, count: 1),
        .tenSeconds: Step(tap: .retry, count: 1),
    ]
    var gap = Gap.medium
    /// Whether your own Done on the Watch is followed by Rest's haptic, as the iPhone follows it with "Rest".
    var restHapticAfterDone = true

    private(set) var plan: Plan?
    private(set) var phase: Phase?
    private(set) var phaseStart = Date.now
    private(set) var isFinished = false
    private(set) var lastCue: String?
    private(set) var log: [LogEntry] = []

    let session = SessionKeeper()

    @ObservationIgnored private var warned = false
    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private let player = Player()

    var schemes: [Scheme] {
        Scheme.candidates + [Scheme(id: "Custom", name: "Your own", patterns: custom.mapValues(\.pattern))]
    }

    var scheme: Scheme { schemes.first { $0.id == schemeID } ?? Scheme.candidates[0] }

    var isInOpenWork: Bool { phase?.kind == .work && phase?.length == nil }

    // MARK: Trying a haptic

    func tryCue(_ cue: CueKind) {
        player.play(scheme.pattern(for: cue), gap: gap)
    }

    func tryPattern(_ pattern: Pattern) {
        player.play(pattern, gap: gap)
    }

    func cycleScheme() {
        let ids = schemes.map(\.id)
        let index = ids.firstIndex(of: schemeID) ?? 0
        schemeID = ids[(index + 1) % ids.count]
        note("Scheme \(schemeID)")
    }

    // MARK: The stand-in Workout

    func start(_ plan: Plan) {
        self.plan = plan
        isFinished = false
        lastCue = nil
        note("Start \(plan.warnsBeforeRestEnds ? "Open Rounds" : "Intervals"), scheme \(schemeID), gap \(gap.label)")
        Task { await session.start(plan.activity) }
        enter(plan.first, at: .now, playsCue: true)
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                self?.step()
            }
        }
    }

    func done() {
        guard let plan, let phase, isInOpenWork, let next = plan.phase(after: phase) else { return }
        note("Done")
        enter(next, at: .now, playsCue: restHapticAfterDone)
    }

    func stop() {
        ticker?.cancel()
        ticker = nil
        session.end()
        if plan != nil { note("Stop") }
        plan = nil
        phase = nil
        isFinished = false
    }

    private func step() {
        guard let plan, let phase, !isFinished else { return }
        let elapsed = Date.now.timeIntervalSince(phaseStart)
        if plan.warnsBeforeRestEnds, phase.kind == .rest, let length = phase.length, length >= 20, !warned,
            elapsed >= length - 10
        {
            warned = true
            fire(.tenSeconds)
        }
        guard let length = phase.length, elapsed >= length else { return }
        let end = phaseStart.addingTimeInterval(length)
        if let next = plan.phase(after: phase) {
            enter(next, at: end, playsCue: true)
        } else {
            finish()
        }
    }

    private func enter(_ next: Phase, at date: Date, playsCue: Bool) {
        phase = next
        phaseStart = date
        warned = false
        guard let cue = next.kind.cue else { return }
        if playsCue {
            fire(cue)
        } else {
            lastCue = "\(cue.name) · no haptic after Done"
            note(lastCue ?? "")
        }
    }

    private func finish() {
        isFinished = true
        phase = nil
        ticker?.cancel()
        ticker = nil
        fire(.complete)
        Task {
            try? await Task.sleep(for: .seconds(3))
            session.end()
        }
    }

    private func fire(_ cue: CueKind) {
        let pattern = scheme.pattern(for: cue)
        player.play(pattern, gap: gap)
        lastCue = "\(cue.name) · \(describe(pattern))"
        note("\(scheme.id) \(lastCue ?? "")")
    }

    private func note(_ text: String) {
        log.insert(LogEntry(date: .now, text: text), at: 0)
    }
}

/// A workout session that keeps the app running with the wrist down. It has no builder, so nothing reaches Health.
@Observable
final class SessionKeeper: NSObject, HKWorkoutSessionDelegate {
    private(set) var status = "No session"
    private(set) var isRunning = false

    @ObservationIgnored private let store = HKHealthStore()
    @ObservationIgnored private var session: HKWorkoutSession?

    func authorize() async {
        do {
            try await store.requestAuthorization(toShare: [HKObjectType.workoutType()], read: [])
        } catch {
            status = "Permission failed: \(error.localizedDescription)"
        }
    }

    func start(_ activity: HKWorkoutActivityType) async {
        end()
        await authorize()
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = activity
        configuration.locationType = .indoor
        do {
            let session = try HKWorkoutSession(healthStore: store, configuration: configuration)
            session.delegate = self
            session.startActivity(with: .now)
            self.session = session
        } catch {
            status = "No session: \(error.localizedDescription)"
        }
    }

    func end() {
        session?.end()
        session = nil
        isRunning = false
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState, date: Date
    ) {
        let running = toState == .running
        let text =
            switch toState {
            case .running: "Session running"
            case .ended, .stopped: "Session ended"
            default: "Session state \(toState.rawValue)"
            }
        Task { @MainActor in
            self.isRunning = running
            self.status = text
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: any Error) {
        let text = "Session failed: \(error.localizedDescription)"
        Task { @MainActor in
            self.isRunning = false
            self.status = text
        }
    }
}
