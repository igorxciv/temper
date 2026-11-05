// PROTOTYPE, throwaway. Answers "How should the Watch running screen look: a large tap target or tap-anywhere?"
// Lives only on the prototype/watch-running-screen branch and is never merged.

import Foundation

/// The three layouts under test, from the smallest tap target to the whole screen.
public enum Variant: String, CaseIterable, Identifiable, Sendable {
    case button = "A"
    case band = "B"
    case anywhere = "C"

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .button: "Large button"
        case .band: "Half-screen band"
        case .anywhere: "Tap anywhere"
        }
    }
}

/// The three moments the ticket asks to cover.
public enum Scenario: String, CaseIterable, Identifiable, Sendable {
    case openWork = "Open Rounds Work"
    case openRest = "Open Rounds Rest"
    case intervalsWork = "Intervals Work"

    public var id: String { rawValue }
}

public enum PhaseKind: Sendable {
    case work
    case rest
}

/// What the quick action means right now.
public enum QuickAction: Equatable, Sendable {
    /// Done in Open Rounds. Disabled during Rest and while Paused, and dimmed in place.
    case done(isEnabled: Bool)
    case pause
    case resume

    public var label: String {
        switch self {
        case .done: "Done"
        case .pause: "Pause"
        case .resume: "Resume"
        }
    }

    public var symbol: String {
        switch self {
        case .done: "checkmark"
        case .pause: "pause.fill"
        case .resume: "play.fill"
        }
    }

    public var isEnabled: Bool {
        if case .done(let isEnabled) = self { isEnabled } else { true }
    }

    /// The hint shown by the tap-anywhere variant, which has no button to label.
    public var hint: String {
        switch self {
        case .done(true): "Tap to finish the set"
        case .done(false): "Work starts by itself"
        case .pause: "Tap to pause"
        case .resume: "Tap to resume"
        }
    }
}

/// Everything one running screen draws at one instant.
public struct Frame: Sendable {
    public var phase: PhaseKind
    public var phaseName: String
    public var time: String
    /// The part of the Phase left, from 1 to 0. `nil` for an open Work, which shows only the empty track.
    public var remaining: Double?
    public var roundLine: String
    /// In Rest, the set just finished: "Work 1:42".
    public var detail: String?
    public var isPaused: Bool
    public var action: QuickAction

    public init(
        phase: PhaseKind, phaseName: String, time: String, remaining: Double?, roundLine: String, detail: String?,
        isPaused: Bool, action: QuickAction
    ) {
        self.phase = phase
        self.phaseName = phaseName
        self.time = time
        self.remaining = remaining
        self.roundLine = roundLine
        self.detail = detail
        self.isPaused = isPaused
        self.action = action
    }
}

/// A stand-in for the iPhone engine: just enough clock to make each scenario move and react to the quick action.
public struct FakeWorkout: Sendable {
    public private(set) var scenario: Scenario
    private var phase: PhaseKind = .work
    private var phaseStart: Date
    private var pausedAt: Date?
    private var round: Int
    private var lastWork: TimeInterval?

    private let openRest: TimeInterval = 60
    private let intervalsWork: TimeInterval = 40
    private let intervalsRest: TimeInterval = 20
    private let intervalsRounds = 8

    private var isOpenRounds: Bool { scenario != .intervalsWork }

    /// Starts each scenario part-way in, so the numbers look like a real set.
    public init(scenario: Scenario, now: Date) {
        self.scenario = scenario
        switch scenario {
        case .openWork:
            round = 3
            phaseStart = now.addingTimeInterval(-42)
        case .openRest:
            round = 3
            phase = .rest
            lastWork = 102
            phaseStart = now.addingTimeInterval(-18)
        case .intervalsWork:
            round = 4
            phaseStart = now.addingTimeInterval(-12)
        }
    }

    private func elapsed(at now: Date) -> TimeInterval {
        (pausedAt ?? now).timeIntervalSince(phaseStart)
    }

    private var length: TimeInterval? {
        switch (isOpenRounds, phase) {
        case (true, .work): nil
        case (true, .rest): openRest
        case (false, .work): intervalsWork
        case (false, .rest): intervalsRest
        }
    }

    /// Moves to the next Phase once a timed one runs out.
    public mutating func advance(to now: Date) {
        guard pausedAt == nil, let length, elapsed(at: now) >= length else { return }
        let end = phaseStart.addingTimeInterval(length)
        switch phase {
        case .work:
            phase = .rest
        case .rest:
            phase = .work
            round = isOpenRounds ? round + 1 : round % intervalsRounds + 1
        }
        phaseStart = end
    }

    /// Returns whether the tap did anything.
    @discardableResult
    public mutating func quickAction(at now: Date) -> Bool {
        if isOpenRounds {
            guard phase == .work, pausedAt == nil else { return false }
            lastWork = elapsed(at: now)
            phase = .rest
            phaseStart = now
            return true
        }
        if let pausedAt {
            phaseStart = phaseStart.addingTimeInterval(now.timeIntervalSince(pausedAt))
            self.pausedAt = nil
        } else {
            pausedAt = now
        }
        return true
    }

    public func frame(at now: Date) -> Frame {
        let elapsed = elapsed(at: now)
        let shown = length.map { max($0 - elapsed, 0).rounded(.up) } ?? elapsed.rounded(.down)
        let action: QuickAction =
            if isOpenRounds {
                .done(isEnabled: phase == .work && pausedAt == nil)
            } else {
                pausedAt == nil ? .pause : .resume
            }
        return Frame(
            phase: phase,
            phaseName: pausedAt == nil ? (phase == .work ? "Work" : "Rest") : "Paused",
            time: Self.clock(shown),
            remaining: length.map { max($0 - elapsed, 0) / $0 },
            roundLine: isOpenRounds ? "Round \(round)" : "Round \(round) of \(intervalsRounds)",
            detail: isOpenRounds && phase == .rest ? lastWork.map { "Work \(Self.short($0))" } : nil,
            isPaused: pausedAt != nil,
            action: action
        )
    }

    /// "00:42", the iPhone running screen's format.
    static func clock(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let minutes = String(format: "%02d", total / 60)
        let rest = String(format: "%02d", total % 60)
        return "\(minutes):\(rest)"
    }

    /// "1:42", the line's format.
    static func short(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        return "\(total / 60):" + String(format: "%02d", total % 60)
    }
}
