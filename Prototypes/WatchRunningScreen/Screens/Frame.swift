// PROTOTYPE, throwaway. Answers "How should each of the Watch's screens look, and which heart-rate reading goes in
// the slot?" (https://github.com/igorxciv/temper/issues/111), building on the running-screen prototype for #76.
// Lives only on the prototype/watch-running-screen branch and is never merged.

import Foundation

// MARK: - What the owner flips between

/// What sits in the running screen's heart-rate slot.
public enum HeartVariant: String, CaseIterable, Identifiable, Sendable {
    case bpm = "H1"
    case zoneNumber = "H2"
    case zoneMeter = "H3"

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .bpm: "bpm only"
        case .zoneNumber: "bpm + zone number"
        case .zoneMeter: "bpm + zone meter"
        }
    }
}

/// Where "iPhone not connected" shows during a dropout. The controls dim in place either way.
public enum DropoutVariant: String, CaseIterable, Identifiable, Sendable {
    case header = "D1"
    case line = "D2"

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .header: "mark replaces the Phase name"
        case .line: "mark replaces the line"
        }
    }
}

/// The secondary page, a swipe right of the running screen.
public enum ControlsVariant: String, CaseIterable, Identifiable, Sendable {
    case stacked = "P1"
    case circles = "P2"

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .stacked: "two wide buttons"
        case .circles: "two round buttons"
        }
    }
}

/// How Stop asks before it ends the Workout.
public enum StopVariant: String, CaseIterable, Identifiable, Sendable {
    case dialog = "S1"
    case tapAgain = "S2"

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .dialog: "\"End this Workout?\" dialog"
        case .tapAgain: "tap again within 3 s"
        }
    }
}

/// What a late Watch shows while its session records in the background.
public enum LateVariant: String, CaseIterable, Identifiable, Sendable {
    case message = "L1"
    case readOnly = "L2"

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .message: "message only"
        case .readOnly: "message + time, no controls"
        }
    }
}

/// The complete screen, after Stop or the Workout's end.
public enum CompleteVariant: String, CaseIterable, Identifiable, Sendable {
    case plain = "C1"
    case heart = "C2"

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .plain: "as the iPhone"
        case .heart: "plus average and max heart rate"
        }
    }
}

// MARK: - The Workout

public enum WorkoutType: String, CaseIterable, Identifiable, Sendable {
    case intervals = "Intervals"
    case stopwatch = "Stopwatch"
    case openRounds = "Open Rounds"

    public var id: String { rawValue }
}

public enum PhaseKind: Sendable {
    case prepare
    case work
    case rest
    case cooldown

    public var name: String {
        switch self {
        case .prepare: "Prepare"
        case .work: "Work"
        case .rest: "Rest"
        case .cooldown: "Cooldown"
        }
    }
}

/// A moment to start a sample Workout at, for the snapshots and the controls page.
public enum Moment: String, CaseIterable, Identifiable, Sendable {
    case prepare = "Prepare"
    case work = "Work"
    case rest = "Rest"
    case cooldown = "Cooldown"
    case paused = "Paused"

    public var id: String { rawValue }

    public func applies(to type: WorkoutType) -> Bool {
        switch (type, self) {
        case (.stopwatch, .rest), (.stopwatch, .cooldown), (.openRounds, .prepare), (.openRounds, .cooldown): false
        default: true
        }
    }
}

/// What the capsule does right now. It mirrors the iPhone's large button.
public enum QuickAction: Equatable, Sendable {
    /// Done in Open Rounds. Dimmed in place outside running Work, and while Paused.
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
}

/// One heart-rate reading, and the zone Temper works out from it. A Series 8 runs watchOS 26, where Apple's zone
/// APIs don't exist, so the zone here uses heart-rate reserve with a stand-in maximum and resting rate.
public struct HeartReading: Sendable {
    public var bpm: Int?

    public static let maximum = 186
    public static let resting = 58

    public init(bpm: Int?) {
        self.bpm = bpm
    }

    /// 1 to 5, at 60, 70, 80 and 90% of heart-rate reserve, as Apple's Workout app splits it by default.
    public var zone: Int? {
        guard let bpm else { return nil }
        let reserve = Double(bpm - Self.resting) / Double(Self.maximum - Self.resting)
        return switch reserve {
        case ..<0.6: 1
        case ..<0.7: 2
        case ..<0.8: 3
        case ..<0.9: 4
        default: 5
        }
    }
}

/// Everything the running screen draws at one instant.
public struct Frame: Sendable {
    public var type: WorkoutType
    public var phase: PhaseKind
    public var time: String
    /// The part of the Phase left, from 1 to 0. `nil` for a Phase that counts up with no end: an open Work.
    public var remaining: Double?
    /// The line under the bar, as under the iPhone's ring. "Paused" replaces it.
    public var line: String
    public var isPaused: Bool
    public var action: QuickAction
    public var heart: HeartReading
}

/// What the complete screen shows.
public struct Summary: Sendable {
    public var type: WorkoutType
    public var total: String
    public var rounds: [String]
    public var averageBPM: Int
    public var maximumBPM: Int
}

/// A stand-in for the iPhone engine: just enough clock to move each Workout Type through its Phases and to react to
/// the quick action, Pause, Resume and Stop.
public struct FakeWorkout: Sendable {
    public let type: WorkoutType
    public private(set) var phase: PhaseKind
    private var phaseStart: Date
    private var pausedAt: Date?
    private var round: Int
    private var lastWork: TimeInterval?
    private var workTimes: [TimeInterval]
    private var activeBefore: TimeInterval
    public private(set) var isFinished = false

    private let prepareLength: TimeInterval = 10
    private let intervalsWork: TimeInterval = 40
    private let intervalsRest: TimeInterval = 20
    private let intervalsRounds = 8
    private let cooldownLength: TimeInterval = 60
    private let stopwatchLength: TimeInterval = 300
    private let openRest: TimeInterval = 60

    /// Starts part-way into the moment, so the numbers look like a real Workout.
    public init(type: WorkoutType, moment: Moment, now: Date) {
        self.type = type
        workTimes = type == .openRounds ? [98, 105] : []
        activeBefore = 0
        switch (type, moment) {
        case (_, .prepare):
            phase = .prepare
            round = 1
            phaseStart = now.addingTimeInterval(-3)
        case (.intervals, .rest):
            phase = .rest
            round = 4
            phaseStart = now.addingTimeInterval(-7)
            activeBefore = 220
        case (.intervals, .cooldown):
            phase = .cooldown
            round = 8
            phaseStart = now.addingTimeInterval(-15)
            activeBefore = 470
        case (.intervals, _):
            phase = .work
            round = 4
            phaseStart = now.addingTimeInterval(-12)
            activeBefore = 190
        case (.stopwatch, _):
            phase = .work
            round = 1
            phaseStart = now.addingTimeInterval(-134)
            activeBefore = 10
        case (.openRounds, .rest):
            phase = .rest
            round = 3
            lastWork = 102
            workTimes.append(102)
            phaseStart = now.addingTimeInterval(-18)
            activeBefore = 425
        case (.openRounds, _):
            phase = .work
            round = 3
            phaseStart = now.addingTimeInterval(-42)
            activeBefore = 323
        }
        if moment == .paused {
            pausedAt = now
        }
    }

    private func elapsed(at now: Date) -> TimeInterval {
        (pausedAt ?? now).timeIntervalSince(phaseStart)
    }

    private var length: TimeInterval? {
        switch (type, phase) {
        case (_, .prepare): prepareLength
        case (_, .cooldown): cooldownLength
        case (.intervals, .work): intervalsWork
        case (.intervals, .rest): intervalsRest
        case (.stopwatch, _): stopwatchLength
        case (.openRounds, .work): nil
        case (.openRounds, .rest): openRest
        }
    }

    /// Whether the Phase counts up: a Stopwatch's Work and an open Phase.
    private var countsUp: Bool { type == .stopwatch && phase == .work || length == nil }

    /// Moves to the next Phase once a timed one runs out.
    public mutating func advance(to now: Date) {
        guard !isFinished, pausedAt == nil, let length, elapsed(at: now) >= length else { return }
        let end = phaseStart.addingTimeInterval(length)
        if phase != .prepare { activeBefore += length }
        switch (type, phase) {
        case (_, .prepare):
            phase = .work
        case (.intervals, .work) where round == intervalsRounds:
            phase = .cooldown
        case (_, .work) where type == .stopwatch:
            isFinished = true
        case (_, .work):
            phase = .rest
        case (_, .rest):
            phase = .work
            round += 1
        case (_, .cooldown):
            isFinished = true
        }
        phaseStart = end
    }

    /// Returns whether the capsule did anything.
    @discardableResult
    public mutating func quickAction(at now: Date) -> Bool {
        if type == .openRounds {
            guard phase == .work, pausedAt == nil else { return false }
            let work = elapsed(at: now)
            lastWork = work
            workTimes.append(work)
            activeBefore += work
            phase = .rest
            phaseStart = now
            return true
        }
        togglePause(at: now)
        return true
    }

    public mutating func togglePause(at now: Date) {
        if let pausedAt {
            phaseStart = phaseStart.addingTimeInterval(now.timeIntervalSince(pausedAt))
            self.pausedAt = nil
        } else {
            pausedAt = now
        }
    }

    public var isPaused: Bool { pausedAt != nil }

    public func frame(at now: Date, bpm: Int?) -> Frame {
        let elapsed = elapsed(at: now)
        let shown = countsUp ? elapsed.rounded(.down) : max((length ?? 0) - elapsed, 0).rounded(.up)
        let action: QuickAction =
            if type == .openRounds {
                .done(isEnabled: phase == .work && pausedAt == nil)
            } else {
                pausedAt == nil ? .pause : .resume
            }
        let remaining: Double? =
            switch (type, phase) {
            case (.openRounds, .work): nil
            case (.stopwatch, .work): min(elapsed / stopwatchLength, 1)
            default: length.map { max($0 - elapsed, 0) / $0 }
            }
        return Frame(
            type: type,
            phase: phase,
            time: Self.clock(shown),
            remaining: remaining,
            line: pausedAt == nil ? line : "Paused",
            isPaused: pausedAt != nil,
            action: action,
            heart: HeartReading(bpm: bpm)
        )
    }

    /// The iPhone's line under the ring.
    private var line: String {
        switch (type, phase) {
        case (.intervals, .prepare): "\(intervalsRounds) Rounds"
        case (.intervals, .cooldown): "\(intervalsRounds) of \(intervalsRounds)"
        case (.intervals, _): "\(round) of \(intervalsRounds)"
        case (.stopwatch, .prepare): "\(Self.clock(stopwatchLength)) Stopwatch"
        case (.stopwatch, _): "of \(Self.clock(stopwatchLength))"
        case (.openRounds, .rest): lastWork.map { "Round \(round) · Work \(Self.short($0))" } ?? "Round \(round)"
        case (.openRounds, _): "Round \(round)"
        }
    }

    public func summary(at now: Date) -> Summary {
        var total = activeBefore
        if phase != .prepare, !isFinished { total += elapsed(at: now) }
        return Summary(
            type: type,
            total: Self.clock(total),
            rounds: workTimes.map { Self.short($0) },
            averageBPM: 132,
            maximumBPM: 171
        )
    }

    /// "00:42", the iPhone running screen's format.
    public static func clock(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    /// "1:42", the line's format.
    public static func short(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        return "\(total / 60):" + String(format: "%02d", total % 60)
    }
}

/// A heart rate that climbs in Work and falls in Rest, so the slot and the zone move.
public enum FakeHeart {
    public static func bpm(type: WorkoutType, phase: PhaseKind, at now: Date) -> Int {
        let wobble = sin(now.timeIntervalSinceReferenceDate / 6) * 6
        let base: Double =
            switch phase {
            case .prepare: 92
            case .work: type == .stopwatch ? 152 : 166
            case .rest: 142
            case .cooldown: 124
            }
        return Int(base + wobble)
    }
}
