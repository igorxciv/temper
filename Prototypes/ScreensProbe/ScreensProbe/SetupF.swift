// PROTOTYPE, throw away. The chosen setup screen: the screen is only the preview, and tapping a
// value opens a sheet with the custom wheel. Each value and sheet wears its Phase's colors, so
// setup previews how the Workout will look. Rounds has no Phase, so it wears brass. This round
// compares three treatments of the labels.
import SwiftUI

enum LabelStyle: String, CaseIterable {
    case thread, serif, edge

    var title: String {
        switch self {
        case .thread: "Thread"
        case .serif: "Italic"
        case .edge: "Edge"
        }
    }

    var next: LabelStyle {
        let all = Self.allCases
        return all[((all.firstIndex(of: self) ?? 0) + 1) % all.count]
    }
}

struct SetupF: View {
    @Bindable var state: ProbeState

    private var colors: ThemeColors { state.theme.colors }
    private var style: LabelStyle { state.labelStyle }

    var body: some View {
        VStack(spacing: 0) {
            rows
            StartButton(state: state)
                .padding(.top, 8)
        }
        .padding(.horizontal)
        .background(colors.background.ignoresSafeArea())
        .navigationTitle("Temper")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $state.editing) { field in
            let sheet = sheetColors(field)
            VStack(spacing: 8) {
                sheetTitle(field).foregroundStyle(sheet.title).padding(.top, 20)
                FieldEditor(state: state, field: field)
                    .foregroundStyle(sheet.text)
            }
            .padding(.horizontal)
            .presentationDetents([.medium])
            .presentationBackground(sheet.background)
        }
    }

    private var rows: some View {
        VStack(spacing: 0) {
            ForEach(Field.allCases) { field in
                Button {
                    state.editing = field
                } label: {
                    row(field)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    "\(field.title) \(field.text(state.values[keyPath: field.keyPath]))")
                if field != .cooldown, style != .thread {
                    Rectangle().fill(colors.separator).frame(height: 1)
                }
            }
        }
        .overlay(alignment: .leading) {
            if style == .thread {
                WorkoutThread(state: state)
                    .frame(width: 36)
                    .allowsHitTesting(false)
            }
        }
    }

    @ViewBuilder
    private func row(_ field: Field) -> some View {
        switch style {
        case .thread:
            HStack {
                Text(field.title)
                    .font(.system(size: 21, weight: .semibold, design: .rounded))
                    .foregroundStyle(titleColor(field))
                Spacer(minLength: 8)
                value(field)
            }
            .padding(.leading, 42)
        case .serif:
            VStack(spacing: 0) {
                Text(field.title)
                    .font(.system(size: 25, weight: .medium, design: .serif).italic())
                    .foregroundStyle(titleColor(field))
                value(field)
            }
        case .edge:
            value(field)
                .frame(maxWidth: .infinity)
                .overlay(alignment: .leading) {
                    EdgeLabel(title: field.title, color: titleColor(field))
                }
        }
    }

    private func value(_ field: Field) -> some View {
        Text(field.text(state.values[keyPath: field.keyPath]))
            .font(.system(size: 52, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(colors.text)
    }

    @ViewBuilder
    private func sheetTitle(_ field: Field) -> some View {
        if style == .serif {
            Text(field.title).font(.system(size: 25, weight: .medium, design: .serif).italic())
        } else {
            Text(field.title).font(.headline)
        }
    }

    private func titleColor(_ field: Field) -> Color {
        field.phaseKind.map { state.theme.phase($0).ring } ?? colors.accent
    }

    private func sheetColors(_ field: Field) -> (background: Color, title: Color, text: Color) {
        guard let kind = field.phaseKind else {
            return (colors.raised, colors.accent, colors.text)
        }
        let phase = state.theme.phase(kind)
        return (phase.background, phase.ring, phase.text)
    }
}

/// The Workout drawn as one line: Prepare, a loop that Work and Rest sit on, then Cooldown. An
/// empty node means the Phase is Off.
private struct WorkoutThread: View {
    let state: ProbeState

    var body: some View {
        Canvas { context, size in
            let colors = state.theme.colors
            let count = CGFloat(Field.allCases.count)
            func center(_ index: Int) -> CGFloat { size.height * (CGFloat(index) + 0.5) / count }
            let left: CGFloat = 8
            let right: CGFloat = 28
            let bottom = center(3) + size.height / count * 0.32
            let line = StrokeStyle(lineWidth: 2, lineCap: .round)

            var thread = Path()
            thread.move(to: CGPoint(x: left, y: center(0)))
            thread.addLine(to: CGPoint(x: left, y: center(4)))
            thread.move(to: CGPoint(x: left, y: center(1)))
            thread.addLine(to: CGPoint(x: right - 14, y: center(1)))
            thread.addQuadCurve(
                to: CGPoint(x: right, y: center(1) + 14),
                control: CGPoint(x: right, y: center(1)))
            thread.addLine(to: CGPoint(x: right, y: bottom - 14))
            thread.addQuadCurve(
                to: CGPoint(x: right - 14, y: bottom),
                control: CGPoint(x: right, y: bottom))
            thread.addLine(to: CGPoint(x: left, y: bottom))
            context.stroke(thread, with: .color(colors.secondary.opacity(0.55)), style: line)

            for (index, field) in Field.allCases.enumerated() {
                let onLoop = field == .work || field == .rest
                let spot = CGPoint(x: onLoop ? right : left, y: center(index))
                let color = field.phaseKind.map { state.theme.phase($0).ring } ?? colors.accent
                let rect = CGRect(x: spot.x - 6, y: spot.y - 6, width: 12, height: 12)
                if state.values[keyPath: field.keyPath] == 0 {
                    context.fill(Path(ellipseIn: rect), with: .color(colors.background))
                    context.stroke(Path(ellipseIn: rect), with: .color(color), lineWidth: 2)
                } else {
                    context.fill(Path(ellipseIn: rect), with: .color(color))
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// The label turned sideways along the row's edge, like a marking on a tool, beside a short rule.
private struct EdgeLabel: View {
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 7) {
            Capsule().fill(color).frame(width: 3, height: 74)
            Text(title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
                .fixedSize()
                .rotationEffect(.degrees(-90))
                .frame(width: 20, height: 74)
        }
    }
}
