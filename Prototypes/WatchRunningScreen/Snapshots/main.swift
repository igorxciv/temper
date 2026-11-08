// PROTOTYPE, throwaway. Renders contact sheets of every Watch screen and variant at the Series 8 display sizes.
// macOS draws SF Pro where the Watch draws SF Compact, so judge layout, not type.
//
//     swift run --package-path Prototypes/WatchRunningScreen Snapshots <output folder>

import AppKit
import Screens
import SwiftUI

/// A Series 8 display in points, with roughly where the system clock sits.
struct WatchSize {
    let name: String
    let width: CGFloat
    let height: CGFloat
    let corner: CGFloat
    let topInset: CGFloat
}

let sizes = [
    WatchSize(name: "45mm", width: 198, height: 242, corner: 41, topInset: 31),
    WatchSize(name: "41mm", width: 176, height: 215, corner: 37, topInset: 28),
]

let now = Date(timeIntervalSinceReferenceDate: 0)

func frame(_ type: WorkoutType, _ moment: Moment) -> Frame {
    let workout = FakeWorkout(type: type, moment: moment, now: now)
    return workout.frame(at: now, bpm: FakeHeart.bpm(type: type, phase: workout.phase, at: now))
}

/// One Watch face: a screen inside the display shape, under the system clock.
struct WatchFace<Content: View>: View {
    let size: WatchSize
    let isAlwaysOn: Bool
    @ViewBuilder let content: Content

    var body: some View {
        content
            .safeAreaPadding(.top, size.topInset)
            .overlay(alignment: .topTrailing) {
                Text("10:09")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isAlwaysOn ? .white.opacity(0.6) : .white)
                    .padding(.top, 8)
                    .padding(.trailing, 16)
            }
            .frame(width: size.width, height: size.height)
            .clipShape(RoundedRectangle(cornerRadius: size.corner, style: .continuous))
            .padding(10)
            .background(RoundedRectangle(cornerRadius: size.corner + 10, style: .continuous).fill(.black))
    }
}

struct Cell: Identifiable {
    let id = UUID()
    let caption: String
    let isAlwaysOn: Bool
    let view: AnyView

    init(_ caption: String, isAlwaysOn: Bool = false, @ViewBuilder _ view: () -> some View) {
        self.caption = caption
        self.isAlwaysOn = isAlwaysOn
        self.view = AnyView(view())
    }
}

struct Row: Identifiable {
    let id = UUID()
    let title: String
    let cells: [Cell]
}

struct Sheet: View {
    let title: String
    let size: WatchSize
    let rows: [Row]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("PROTOTYPE · \(title) · Series 8 \(size.name) (\(Int(size.width))×\(Int(size.height)) pt)")
                .font(.system(size: 20, weight: .bold))
            Grid(alignment: .topLeading, horizontalSpacing: 24, verticalSpacing: 14) {
                ForEach(rows) { row in
                    GridRow {
                        Text(row.title)
                            .font(.system(size: 15, weight: .semibold))
                            .frame(width: 130, alignment: .leading)
                        ForEach(row.cells) { cell in
                            VStack(spacing: 6) {
                                WatchFace(size: size, isAlwaysOn: cell.isAlwaysOn) { cell.view }
                                Text(cell.caption)
                                    .font(.system(size: 13, weight: .medium))
                                    .frame(width: size.width + 20)
                                    .multilineTextAlignment(.center)
                            }
                        }
                    }
                }
            }
        }
        .padding(28)
        .foregroundStyle(.black)
        .background(Color(white: 0.93))
        .environment(\.colorScheme, .dark)
    }
}

// MARK: - Sheets

@MainActor
func running(_ frame: Frame, heart: HeartVariant, isAlwaysOn: Bool = false, dropout: DropoutVariant? = nil)
    -> some View
{
    RunningScreen(input: ScreenInput(frame: frame, isAlwaysOn: isAlwaysOn, heart: heart, dropout: dropout, tap: {}))
}

var runningRows: [Row] {
    var rows: [Row] = []
    for type in WorkoutType.allCases {
        for moment in Moment.allCases where moment.applies(to: type) {
            let f = frame(type, moment)
            rows.append(
                Row(
                    title: "\(type.rawValue)\n\(moment.rawValue)",
                    cells: HeartVariant.allCases.map { heart in
                        Cell("\(heart.rawValue) · \(heart.name)") { running(f, heart: heart) }
                    } + [
                        Cell("H3 · Always On", isAlwaysOn: true) { running(f, heart: .zoneMeter, isAlwaysOn: true) }
                    ]))
        }
    }
    return rows
}

var screenRows: [Row] {
    let openWork = frame(.openRounds, .work)
    // A Rest that ran out during the dropout: held at 00:00, not moved on to the next Work.
    var heldRest = frame(.intervals, .rest)
    heldRest.time = "00:00"
    heldRest.remaining = 0
    let stopwatch = frame(.stopwatch, .work)
    let intervalsSummary = FakeWorkout(type: .intervals, moment: .cooldown, now: now).summary(at: now)
    let roundsSummary = FakeWorkout(type: .openRounds, moment: .rest, now: now).summary(at: now)

    func controls(_ variant: ControlsVariant, paused: Bool = false, connected: Bool = true, armed: Bool = false)
        -> some View
    {
        ControlsPage(
            variant: variant, isPaused: paused, isConnected: connected, isStopArmed: armed, isAlwaysOn: false,
            pause: {}, stop: {})
    }

    return [
        Row(
            title: "Outside a Workout",
            cells: [
                Cell("Idle · \"Start on iPhone\"") { IdleScreen(isAlwaysOn: false) },
                Cell("Waiting for the first message") { WaitingScreen(isAlwaysOn: false) },
                Cell("L1 · \(LateVariant.message.name)") {
                    RunningOnIPhoneScreen(variant: .message, frame: stopwatch, isAlwaysOn: false)
                },
                Cell("L2 · \(LateVariant.readOnly.name)") {
                    RunningOnIPhoneScreen(variant: .readOnly, frame: stopwatch, isAlwaysOn: false)
                },
            ]),
        Row(
            title: "Dropout",
            cells: [
                Cell("D1 · \(DropoutVariant.header.name)") { running(openWork, heart: .zoneNumber, dropout: .header) },
                Cell("D2 · \(DropoutVariant.line.name)") { running(openWork, heart: .zoneNumber, dropout: .line) },
                Cell("D2 · a Rest held at 00:00") { running(heldRest, heart: .zoneNumber, dropout: .line) },
                Cell("D2 · Always On", isAlwaysOn: true) {
                    running(openWork, heart: .zoneNumber, isAlwaysOn: true, dropout: .line)
                },
            ]),
        Row(
            title: "Secondary page\n(swipe right)",
            cells: [
                Cell("P1 · \(ControlsVariant.stacked.name)") { controls(.stacked) },
                Cell("P1 · Paused") { controls(.stacked, paused: true) },
                Cell("P2 · \(ControlsVariant.circles.name)") { controls(.circles) },
                Cell("P2 · Paused") { controls(.circles, paused: true) },
            ]),
        Row(
            title: "Stop's confirmation",
            cells: [
                Cell("S1 · \(StopVariant.dialog.name)") { StopDialogMock() },
                Cell("S2 · P1 after one tap") { controls(.stacked, armed: true) },
                Cell("S2 · P2 after one tap") { controls(.circles, armed: true) },
                Cell("P1 · not connected") { controls(.stacked, connected: false) },
            ]),
        Row(
            title: "Complete",
            cells: [
                Cell("C1 · Intervals") {
                    CompleteScreen(
                        variant: .plain, summary: intervalsSummary, isAlwaysOn: false, scrolls: false, done: {})
                },
                Cell("C2 · Intervals") {
                    CompleteScreen(
                        variant: .heart, summary: intervalsSummary, isAlwaysOn: false, scrolls: false, done: {})
                },
                Cell("C1 · Open Rounds") {
                    CompleteScreen(variant: .plain, summary: roundsSummary, isAlwaysOn: false, scrolls: false, done: {})
                },
                Cell("C2 · Open Rounds") {
                    CompleteScreen(variant: .heart, summary: roundsSummary, isAlwaysOn: false, scrolls: false, done: {})
                },
            ]),
    ]
}

let folder = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? ".")
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
for size in sizes {
    for (name, title, rows) in [
        ("watch-running", "Watch running screen and heart-rate slot", runningRows),
        ("watch-screens", "Every other Watch screen", screenRows),
    ] {
        let renderer = ImageRenderer(content: Sheet(title: title, size: size, rows: rows))
        renderer.scale = 2
        guard let image = renderer.cgImage else { fatalError("Rendering \(name) \(size.name) failed") }
        let file = folder.appending(path: "\(name)-\(size.name).png")
        let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
        try png?.write(to: file)
        print(file.path)
    }
}
