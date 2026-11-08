// PROTOTYPE, throwaway. Runs on the Series 8. The home list picks a scheme, tries each Cue's haptic, and starts a
// stand-in Workout to wear through real sets. See README.md.

import SwiftUI

@main
struct PrototypeApp: App {
    @State private var rig = Rig()

    var body: some Scene {
        WindowGroup {
            HomeView(rig: rig)
        }
    }
}

enum IntervalsChoice: CaseIterable, Identifiable {
    case twentyTen, fortyTwenty, sixtyThirty, threeOne

    var id: Self { self }

    var work: TimeInterval {
        switch self {
        case .twentyTen: 20
        case .fortyTwenty: 40
        case .sixtyThirty: 60
        case .threeOne: 180
        }
    }

    var rest: TimeInterval {
        switch self {
        case .twentyTen: 10
        case .fortyTwenty: 20
        case .sixtyThirty: 30
        case .threeOne: 60
        }
    }

    var label: String { "\(clock(work)) / \(clock(rest))" }
}

func clock(_ seconds: TimeInterval) -> String {
    let whole = max(0, Int(seconds.rounded(.up)))
    return String(format: "%d:%02d", whole / 60, whole % 60)
}

extension PhaseKind {
    /// The ring colors of Temper's Phases, from `Shared/Ink.swift`.
    var tint: Color {
        switch self {
        case .prepare: Color(red: 0x8F / 255, green: 0xCB / 255, blue: 0xEF / 255)
        case .work: Color(red: 0xFF / 255, green: 0xAE / 255, blue: 0x8A / 255)
        case .rest: Color(red: 0x86 / 255, green: 0xDC / 255, blue: 0xCB / 255)
        case .cooldown: Color(red: 0xAF / 255, green: 0xC4 / 255, blue: 0xFF / 255)
        }
    }
}

struct HomeView: View {
    @Bindable var rig: Rig

    @State private var intervals = IntervalsChoice.fortyTwenty
    @State private var rounds = 8
    @State private var cooldown = true
    @State private var openRest: TimeInterval = 90

    var body: some View {
        NavigationStack {
            List {
                Section("Scheme") {
                    Picker("Scheme", selection: $rig.schemeID) {
                        ForEach(rig.schemes) { scheme in
                            Text("\(scheme.id) \(scheme.name)").tag(scheme.id)
                        }
                    }
                    ForEach(CueKind.allCases) { cue in
                        Button {
                            rig.tryCue(cue)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(cue.name)
                                Text(describe(rig.scheme.pattern(for: cue)))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    NavigationLink("Edit your own") { CustomView(rig: rig) }
                }

                Section("Intervals") {
                    Picker("Work / Rest", selection: $intervals) {
                        ForEach(IntervalsChoice.allCases) { Text($0.label).tag($0) }
                    }
                    Picker("Rounds", selection: $rounds) {
                        ForEach([4, 8, 12], id: \.self) { Text("\($0)").tag($0) }
                    }
                    Toggle("Cooldown 1:00", isOn: $cooldown)
                    Button("Start Intervals") {
                        rig.start(
                            .intervals(work: intervals.work, rest: intervals.rest, rounds: rounds, cooldown: cooldown))
                    }
                }

                Section("Open Rounds") {
                    Picker("Rest", selection: $openRest) {
                        ForEach([30, 60, 90, 120, 180] as [TimeInterval], id: \.self) { Text(clock($0)).tag($0) }
                    }
                    Toggle("Rest haptic after Done", isOn: $rig.restHapticAfterDone)
                    Button("Start Open Rounds") { rig.start(.openRounds(rest: openRest)) }
                }

                Section("More") {
                    Picker("Gap", selection: $rig.gap) {
                        ForEach(Gap.allCases) { Text($0.label).tag($0) }
                    }
                    NavigationLink("Every haptic") { LabView(rig: rig) }
                    NavigationLink("Log (\(rig.log.count))") { LogView(rig: rig) }
                    Text(rig.session.status)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Haptics")
        }
        .fullScreenCover(isPresented: isRunning) {
            RunView(rig: rig)
        }
        .task { await rig.session.authorize() }
    }

    private var isRunning: Binding<Bool> {
        Binding(
            get: { rig.plan != nil },
            set: { if !$0 { rig.stop() } })
    }
}

struct RunView: View {
    let rig: Rig

    @State private var isStopArmed = false
    @State private var disarm: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 2) {
            HStack {
                Button(rig.scheme.id) { rig.cycleScheme() }
                    .frame(width: 64)
                Spacer()
                Button(isStopArmed ? "Again" : "Stop", role: .destructive) { tapStop() }
                    .frame(width: 72)
            }
            .font(.footnote)

            TimelineView(.periodic(from: .now, by: 0.5)) { context in
                VStack(spacing: 0) {
                    Text(rig.isFinished ? "Complete" : rig.phase?.kind.name ?? "")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(rig.phase?.kind.tint ?? .white)
                    Text(time(at: context.date))
                        .font(.system(size: 44, weight: .semibold).monospacedDigit())
                    Text(roundText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Text(rig.lastCue ?? " ")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if !rig.session.isRunning {
                Text("No session: haptics stop with the wrist down")
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }

            if rig.plan?.warnsBeforeRestEnds == true {
                Button("Done") { rig.done() }
                    .font(.system(size: 20, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(Capsule().fill(PhaseKind.work.tint.opacity(rig.isInOpenWork ? 1 : 0.25)))
                    .foregroundStyle(.black)
                    .buttonStyle(.plain)
                    .disabled(!rig.isInOpenWork)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var roundText: String {
        guard let phase = rig.phase, phase.round > 0 else { return " " }
        if let rounds = rig.plan?.rounds { return "Round \(phase.round) of \(rounds)" }
        return "Round \(phase.round)"
    }

    private func time(at date: Date) -> String {
        guard let phase = rig.phase else { return "0:00" }
        let elapsed = date.timeIntervalSince(rig.phaseStart)
        guard let length = phase.length else { return clock(elapsed.rounded(.down)) }
        return clock(length - elapsed)
    }

    /// Stop ends on a second tap within 3 s, as the Watch's secondary page will.
    private func tapStop() {
        if isStopArmed {
            disarm?.cancel()
            rig.stop()
            return
        }
        isStopArmed = true
        disarm = Task {
            try? await Task.sleep(for: .seconds(3))
            if !Task.isCancelled { isStopArmed = false }
        }
    }
}

struct LabView: View {
    let rig: Rig

    @State private var count = 1

    var body: some View {
        List {
            Stepper("Play ×\(count)", value: $count, in: 1...3)
            ForEach(Tap.allCases) { tap in
                Button(tap.label) { rig.tryPattern(Array(repeating: tap, count: count)) }
            }
        }
        .navigationTitle("Every haptic")
    }
}

struct CustomView: View {
    @Bindable var rig: Rig

    var body: some View {
        List {
            Text("Pick \"Custom Your own\" as the scheme to run with these.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            ForEach(CueKind.allCases) { cue in
                Section(cue.name) {
                    Picker("Haptic", selection: step(cue).tap) {
                        ForEach(Tap.allCases) { Text($0.label).tag($0) }
                    }
                    Stepper("×\(step(cue).wrappedValue.count)", value: step(cue).count, in: 1...3)
                    Button("Play") { rig.tryPattern(step(cue).wrappedValue.pattern) }
                }
            }
        }
        .navigationTitle("Your own")
    }

    private func step(_ cue: CueKind) -> Binding<Step> {
        Binding(
            get: { rig.custom[cue] ?? .fallback },
            set: { rig.custom[cue] = $0 })
    }
}

struct LogView: View {
    let rig: Rig

    var body: some View {
        List(rig.log) { entry in
            VStack(alignment: .leading) {
                Text(entry.text)
                    .font(.footnote)
                Text(entry.date, format: .dateTime.hour().minute().second())
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Log")
    }
}
