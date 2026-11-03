// PROTOTYPE, throw away. The five Workout Type pickers from the ticket, each with its own place for Settings.
import SwiftUI
import TemperCore

/// Setup as the chosen picker shows it. Every variant opens straight onto the last-used type.
struct ProbeHome: View {
    let probe: ProbeState
    let remembered: RememberedValues
    let start: (WorkoutType, Workout) -> Void

    var body: some View {
        Group {
            switch probe.variant {
            case .a: SegmentedHome(probe: probe, remembered: remembered, start: start)
            case .b: TitleMenuHome(probe: probe, remembered: remembered, start: start)
            case .c: SwipePagesHome(probe: probe, remembered: remembered, start: start)
            case .d: TabBarHome(probe: probe, remembered: remembered, start: start)
            case .e: ListHome(probe: probe, remembered: remembered, start: start)
            }
        }
        .onAppear {
            guard probe.autostart else { return }
            probe.autostart = false
            let settings = probe.type == .intervals ? remembered.settings : probe.stopwatch
            start(probe.type, settings.makeWorkout())
        }
    }
}

/// One type's setup, reading and writing that type's own values.
private struct TypeSetup: View {
    let type: WorkoutType
    let probe: ProbeState
    let remembered: RememberedValues
    let start: (WorkoutType, Workout) -> Void

    var body: some View {
        SetupScreen(settings: settings, values: type.values) { start(type, $0) }
    }

    private var settings: Binding<WorkoutSettings> {
        switch type {
        case .intervals:
            Binding {
                remembered.settings
            } set: {
                remembered.settings = $0
            }
        case .stopwatch:
            Binding {
                probe.stopwatch
            } set: {
                probe.stopwatch = $0
            }
        }
    }
}

private struct SettingsButton: View {
    let remembered: RememberedValues

    var body: some View {
        NavigationLink {
            SettingsScreen(remembered: remembered)
        } label: {
            Label("Settings", systemImage: "gearshape")
        }
    }
}

// MARK: - (a) Segmented control in the navigation bar

private struct SegmentedHome: View {
    @Bindable var probe: ProbeState
    let remembered: RememberedValues
    let start: (WorkoutType, Workout) -> Void

    var body: some View {
        NavigationStack {
            TypeSetup(type: probe.type, probe: probe, remembered: remembered, start: start)
                .navigationTitle(probe.type.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Picker("Workout Type", selection: $probe.type) {
                            ForEach(WorkoutType.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .fixedSize()
                    }
                    ToolbarItem(placement: .topBarTrailing) { SettingsButton(remembered: remembered) }
                }
                .probeBar(probe)
        }
    }
}

// MARK: - (b) Menu on the navigation title

private struct TitleMenuHome: View {
    @Bindable var probe: ProbeState
    let remembered: RememberedValues
    let start: (WorkoutType, Workout) -> Void

    var body: some View {
        NavigationStack {
            TypeSetup(type: probe.type, probe: probe, remembered: remembered, start: start)
                .navigationTitle(probe.type.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbarTitleMenu {
                    Picker("Workout Type", selection: $probe.type) {
                        ForEach(WorkoutType.allCases) { Label($0.title, systemImage: $0.systemImage).tag($0) }
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) { SettingsButton(remembered: remembered) }
                }
                .probeBar(probe)
        }
    }
}

// MARK: - (c) Swiping horizontally between pages

private struct SwipePagesHome: View {
    @Bindable var probe: ProbeState
    let remembered: RememberedValues
    let start: (WorkoutType, Workout) -> Void

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let colors = InkColors(contrast: contrast)

        NavigationStack {
            TabView(selection: $probe.type) {
                ForEach(WorkoutType.allCases) { type in
                    TypeSetup(type: type, probe: probe, remembered: remembered, start: start)
                        .tag(type)
                }
            }
            // The system dots would sit on Start, so they move up under the title.
            .tabViewStyle(.page(indexDisplayMode: .never))
            .background(colors.background.ignoresSafeArea())
            .navigationTitle(probe.type.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 5) {
                        Text(probe.type.title).font(.headline)
                        HStack(spacing: 7) {
                            ForEach(WorkoutType.allCases) { type in
                                Circle()
                                    .fill(type == probe.type ? colors.text : colors.secondary.opacity(0.4))
                                    .frame(width: 7, height: 7)
                            }
                        }
                    }
                    .foregroundStyle(colors.text)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(probe.type.title)
                    .accessibilityValue("Page \((WorkoutType.allCases.firstIndex(of: probe.type) ?? 0) + 1) of 2")
                }
                ToolbarItem(placement: .topBarTrailing) { SettingsButton(remembered: remembered) }
            }
            .probeBar(probe)
        }
    }
}

// MARK: - (d) Tab bar, one tab per Workout Type, with Settings as its own tab

private enum ProbeTab: Hashable {
    case type(WorkoutType)
    case settings
}

private struct TabBarHome: View {
    let probe: ProbeState
    let remembered: RememberedValues
    let start: (WorkoutType, Workout) -> Void

    @State private var isOnSettings = false

    var body: some View {
        TabView(selection: selection) {
            ForEach(WorkoutType.allCases) { type in
                Tab(type.title, systemImage: type.systemImage, value: ProbeTab.type(type)) {
                    NavigationStack {
                        TypeSetup(type: type, probe: probe, remembered: remembered, start: start)
                            .navigationTitle(type.title)
                            .navigationBarTitleDisplayMode(.inline)
                            .probeBar(probe)
                    }
                }
            }
            Tab("Settings", systemImage: "gearshape", value: ProbeTab.settings) {
                NavigationStack {
                    SettingsScreen(remembered: remembered)
                        .probeBar(probe)
                }
            }
        }
    }

    /// Settings is a tab, but it never becomes the last-used type.
    private var selection: Binding<ProbeTab> {
        Binding {
            isOnSettings ? .settings : .type(probe.type)
        } set: { tab in
            switch tab {
            case .type(let type):
                probe.type = type
                isOnSettings = false
            case .settings:
                isOnSettings = true
            }
        }
    }
}

// MARK: - (e) A list home that pushes into each setup

private struct ListHome: View {
    let probe: ProbeState
    let remembered: RememberedValues
    let start: (WorkoutType, Workout) -> Void

    /// Starts on the last-used type, so Back is the way to the list.
    @State private var path: [WorkoutType] = []

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let colors = InkColors(contrast: contrast)

        NavigationStack(path: $path) {
            List {
                ForEach(WorkoutType.allCases) { type in
                    NavigationLink(value: type) {
                        HStack(spacing: 16) {
                            Image(systemName: type.systemImage)
                                .font(.title)
                                .foregroundStyle(colors.accent)
                                .frame(width: 44)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(type.title).font(.title2.bold())
                                Text(summary(of: type))
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(colors.secondary)
                            }
                        }
                        .padding(.vertical, 10)
                    }
                    .listRowBackground(colors.raised)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .foregroundStyle(colors.text)
            .background(colors.background.ignoresSafeArea())
            .navigationTitle("Temper")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { SettingsButton(remembered: remembered) }
            }
            .navigationDestination(for: WorkoutType.self) { type in
                TypeSetup(type: type, probe: probe, remembered: remembered, start: start)
                    .navigationTitle(type.title)
                    .navigationBarTitleDisplayMode(.inline)
                    .probeBar(probe)
            }
            .probeBar(probe)
        }
        .onAppear { if !probe.atList { path = [probe.type] } }
        .onChange(of: path) {
            if let type = path.last { probe.type = type }
        }
    }

    private func summary(of type: WorkoutType) -> String {
        switch type {
        case .intervals:
            let values = remembered.settings
            return "\(values.rounds) × \(values.work.clockText) / \(values.rest.clockText) · "
                + values.makeWorkout().totalDuration.clockText
        case .stopwatch:
            return "Counts up to \(probe.stopwatch.work.clockText)"
        }
    }
}
