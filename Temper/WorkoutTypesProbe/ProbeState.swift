// PROTOTYPE, throw away. Workout Types Probe compares five ways to pick a Workout Type, and a Stopwatch's
// screens. Nothing here ships, and only the verdict moves on. See Prototypes/WorkoutTypesProbe/README.md.
import Foundation
import Observation
import TemperCore

enum WorkoutType: String, CaseIterable, Identifiable, Hashable {
    case intervals, stopwatch

    var id: Self { self }

    var title: String {
        switch self {
        case .intervals: "Intervals"
        case .stopwatch: "Stopwatch"
        }
    }

    var systemImage: String {
        switch self {
        case .intervals: "repeat"
        case .stopwatch: "stopwatch"
        }
    }

    /// The setup rows, top to bottom.
    var values: [WorkoutValue] {
        switch self {
        case .intervals: WorkoutValue.allCases
        case .stopwatch: [.prepare, .work]
        }
    }
}

/// The five pickers in the ticket, (a) to (e).
enum PickerVariant: String, CaseIterable {
    case a, b, c, d, e

    var name: String {
        switch self {
        case .a: "Segmented"
        case .b: "Title menu"
        case .c: "Swipe pages"
        case .d: "Tab bar"
        case .e: "List home"
        }
    }
}

/// What a running Stopwatch shows under the ring, in place of the Round line.
enum StopwatchLine: String, CaseIterable {
    case length, left, none

    var name: String {
        switch self {
        case .length: "of length"
        case .left: "time left"
        case .none: "nothing"
        }
    }
}

/// Launch arguments set the first state, for example `-variant d -type stopwatch -line left -noBar YES`.
/// The Stopwatch's values are held in memory only.
@Observable
final class ProbeState {
    var variant: PickerVariant
    /// The last-used Workout Type. Setup opens onto it.
    var type: WorkoutType
    /// The type of the Workout running now, which decides how the running screen counts.
    var runningType: WorkoutType = .intervals
    /// Held in memory only. A Stopwatch is one Round with no Rest or Cooldown, so it builds `[Prepare, Work]`.
    var stopwatch = WorkoutSettings(prepare: .seconds(10), rounds: 1, work: .seconds(600), rest: .zero, cooldown: .zero)
    var line: StopwatchLine
    var isBarVisible = true
    let noBar: Bool
    /// `-autostart YES` starts the last-used type at launch, and `-atList YES` leaves (e) on its list.
    var autostart: Bool
    let atList: Bool

    init() {
        let arguments = UserDefaults.standard
        variant = PickerVariant(rawValue: arguments.string(forKey: "variant")?.lowercased() ?? "") ?? .a
        type = WorkoutType(rawValue: arguments.string(forKey: "type") ?? "") ?? .intervals
        line = StopwatchLine(rawValue: arguments.string(forKey: "line") ?? "") ?? .length
        noBar = arguments.bool(forKey: "noBar")
        autostart = arguments.bool(forKey: "autostart")
        atList = arguments.bool(forKey: "atList")
    }

    func cycleVariant(by step: Int) {
        let all = PickerVariant.allCases
        let index = all.firstIndex(of: variant) ?? 0
        variant = all[(index + step + all.count) % all.count]
    }

    func cycleLine() {
        let all = StopwatchLine.allCases
        line = all[((all.firstIndex(of: line) ?? 0) + 1) % all.count]
    }
}
