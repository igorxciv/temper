// PROTOTYPE, throwaway. Every haptic watchOS offers, the Cue kinds the wrist has to tell apart, and the candidate
// schemes that map one to the other. Answers issue #112.

import WatchKit

/// One of watchOS's built-in haptics, named as `WKHapticType` names it.
enum Tap: String, CaseIterable, Identifiable {
    case notification, directionUp, directionDown, success, failure, retry, start, stop, click
    case navigationLeftTurn, navigationRightTurn, navigationGenericManeuver
    case underwaterDepthPrompt, underwaterDepthCriticalPrompt

    var id: Self { self }

    var type: WKHapticType {
        switch self {
        case .notification: .notification
        case .directionUp: .directionUp
        case .directionDown: .directionDown
        case .success: .success
        case .failure: .failure
        case .retry: .retry
        case .start: .start
        case .stop: .stop
        case .click: .click
        case .navigationLeftTurn: .navigationLeftTurn
        case .navigationRightTurn: .navigationRightTurn
        case .navigationGenericManeuver: .navigationGenericManeuver
        case .underwaterDepthPrompt: .underwaterDepthPrompt
        case .underwaterDepthCriticalPrompt: .underwaterDepthCriticalPrompt
        }
    }

    /// A short name that fits a Watch row.
    var label: String {
        switch self {
        case .navigationLeftTurn: "leftTurn"
        case .navigationRightTurn: "rightTurn"
        case .navigationGenericManeuver: "maneuver"
        case .underwaterDepthPrompt: "depth"
        case .underwaterDepthCriticalPrompt: "depthCritical"
        default: rawValue
        }
    }
}

/// The haptics one Cue plays, one after another, a gap apart.
typealias Pattern = [Tap]

/// "notification ×2", "success, notification".
func describe(_ pattern: Pattern) -> String {
    var runs: [(tap: Tap, count: Int)] = []
    for tap in pattern {
        if let last = runs.last, last.tap == tap {
            runs[runs.count - 1].count += 1
        } else {
            runs.append((tap, 1))
        }
    }
    if runs.isEmpty { return "nothing" }
    return runs.map { $0.count == 1 ? $0.tap.label : "\($0.tap.label) ×\($0.count)" }.joined(separator: ", ")
}

/// The Cues Temper speaks. Prepare starts silently, so it has none.
enum CueKind: CaseIterable, Identifiable {
    case work, rest, cooldown, complete, tenSeconds

    var id: Self { self }

    var name: String {
        switch self {
        case .work: "Work"
        case .rest: "Rest"
        case .cooldown: "Cooldown"
        case .complete: "Workout complete"
        case .tenSeconds: "10 seconds"
        }
    }
}

/// One haptic repeated, the shape the Custom scheme is edited in.
struct Step: Hashable {
    var tap: Tap
    var count: Int

    var pattern: Pattern { Array(repeating: tap, count: count) }

    static let fallback = Step(tap: .notification, count: 1)
}

/// A haptic for every Cue kind.
struct Scheme: Identifiable {
    let id: String
    let name: String
    let patterns: [CueKind: Pattern]

    func pattern(for cue: CueKind) -> Pattern { patterns[cue] ?? [] }

    static let candidates: [Scheme] = [
        Scheme(
            id: "A", name: "Apple's names",
            patterns: [
                .work: [.start], .rest: [.stop], .cooldown: [.directionDown], .complete: [.success],
                .tenSeconds: [.retry],
            ]),
        Scheme(
            id: "B", name: "Counted",
            patterns: [
                .work: [.notification, .notification], .rest: [.notification],
                .cooldown: [.notification, .notification, .notification], .complete: [.success, .success],
                .tenSeconds: [.click, .click, .click],
            ]),
        Scheme(
            id: "C", name: "Up and down",
            patterns: [
                .work: [.directionUp], .rest: [.directionDown], .cooldown: [.directionDown, .directionDown],
                .complete: [.success], .tenSeconds: [.click, .click],
            ]),
        Scheme(
            id: "D", name: "Strongest",
            patterns: [
                .work: [.underwaterDepthCriticalPrompt], .rest: [.notification, .notification],
                .cooldown: [.underwaterDepthPrompt], .complete: [.success, .notification], .tenSeconds: [.retry],
            ]),
        Scheme(
            id: "E", name: "Turns",
            patterns: [
                .work: [.navigationRightTurn], .rest: [.navigationLeftTurn], .cooldown: [.navigationGenericManeuver],
                .complete: [.success], .tenSeconds: [.click, .click, .click],
            ]),
    ]
}

/// The space between the haptics of one Cue, from the start of one to the start of the next.
enum Gap: Double, CaseIterable, Identifiable {
    case short = 0.4
    case medium = 0.7
    case long = 1.0

    var id: Self { self }
    var label: String { "\(rawValue.formatted()) s" }
}

/// Plays a pattern, one haptic per gap. A new pattern cuts the one still playing.
final class Player {
    private var playing: Task<Void, Never>?

    func play(_ pattern: Pattern, gap: Gap) {
        playing?.cancel()
        playing = Task {
            for (index, tap) in pattern.enumerated() {
                if index > 0 {
                    try? await Task.sleep(for: .seconds(gap.rawValue))
                    if Task.isCancelled { return }
                }
                WKInterfaceDevice.current().play(tap.type)
            }
        }
    }
}
