// PROTOTYPE, throwaway. Renders contact sheets of every variant against every scenario, awake and Always On, at
// the Series 8 display sizes. macOS draws SF Pro where the Watch draws SF Compact, so judge layout, not type.
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

/// One Watch face: the variant inside the display shape, under the system clock.
struct WatchFace: View {
    let size: WatchSize
    let variant: Variant
    let frame: Frame
    let isAlwaysOn: Bool

    var body: some View {
        RunningScreen(
            variant: variant,
            input: ScreenInput(frame: frame, isAlwaysOn: isAlwaysOn, showsHeartRate: true, tap: {})
        )
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

struct Sheet: View {
    let size: WatchSize
    let now = Date(timeIntervalSinceReferenceDate: 0)

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("PROTOTYPE · Watch running screen · Series 8 \(size.name) (\(Int(size.width))×\(Int(size.height)) pt)")
                .font(.system(size: 20, weight: .bold))
            Grid(horizontalSpacing: 24, verticalSpacing: 18) {
                GridRow {
                    Text("")
                    ForEach(Variant.allCases) { variant in
                        Text("\(variant.rawValue) · \(variant.name)").font(.system(size: 17, weight: .semibold))
                    }
                }
                ForEach(Scenario.allCases) { scenario in
                    ForEach([false, true], id: \.self) { isAlwaysOn in
                        GridRow {
                            Text("\(scenario.rawValue)\(isAlwaysOn ? "\nAlways On" : "")")
                                .font(.system(size: 15, weight: .medium))
                                .frame(width: 130, alignment: .leading)
                            ForEach(Variant.allCases) { variant in
                                WatchFace(
                                    size: size, variant: variant,
                                    frame: FakeWorkout(scenario: scenario, now: now).frame(at: now),
                                    isAlwaysOn: isAlwaysOn)
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

let folder = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? ".")
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
for size in sizes {
    let renderer = ImageRenderer(content: Sheet(size: size))
    renderer.scale = 2
    guard let image = renderer.cgImage else { fatalError("Rendering \(size.name) failed") }
    let file = folder.appending(path: "watch-running-\(size.name).png")
    let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    try png?.write(to: file)
    print(file.path)
}
