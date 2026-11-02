// PROTOTYPE, throw away. Pick a configuration, run it, read the state.
import SwiftUI

@main
struct TimingProbeApp: App {
    var body: some Scene {
        WindowGroup { ProbeView() }
    }
}

@MainActor
@Observable
final class ProbeModel {
    var config = RunConfig()
    var bank: CueBank?
    var log: RunLog?
    var probe: Probe?
    var paused = false
    var logs: [URL] = []

    func load() async {
        refreshLogs()
        if bank == nil { bank = await CueRenderer.render() }
        // For Simulator checks: -autostart <dip index>.
        let arguments = ProcessInfo.processInfo.arguments
        if let flag = arguments.firstIndex(of: "-autostart"), log == nil {
            config.dip = DipMode.allCases[Int(arguments[flag + 1]) ?? 0]
            config.note = "simulator"
            start()
        }
    }

    func start() {
        guard let bank else { return }
        let stamp = Date().formatted(
            .iso8601.year().month().day().time(includingFractionalSeconds: false).timeSeparator(
                .omitted))
        let log = RunLog(name: "run-\(stamp)")
        let probe = Probe(config: config, log: log, cues: bank)
        self.log = log
        self.probe = probe
        paused = false
        UIApplication.shared.isIdleTimerDisabled = true
        Task { await probe.run() }
    }

    func clear() {
        UIApplication.shared.isIdleTimerDisabled = false
        log = nil
        probe = nil
        refreshLogs()
    }

    func refreshLogs() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let files =
            (try? FileManager.default.contentsOfDirectory(at: docs, includingPropertiesForKeys: nil))
            ?? []
        logs = files.filter { $0.pathExtension == "jsonl" }.sorted {
            $0.lastPathComponent > $1.lastPathComponent
        }
    }
}

struct ProbeView: View {
    @State private var model = ProbeModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if let log = model.log {
                RunningView(model: model, log: log)
            } else {
                setup
            }
        }
        .task { await model.load() }
        .onChange(of: scenePhase) { _, phase in
            model.log?.write("scene", ["phase": "\(phase)"])
            if phase == .active, model.log != nil {
                UIApplication.shared.isIdleTimerDisabled = true
                let probe = model.probe
                Task { await probe?.recover("foreground") }
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIApplication.protectedDataWillBecomeUnavailableNotification)
        ) { _ in
            model.log?.write("locked")
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIApplication.protectedDataDidBecomeAvailableNotification)
        ) { _ in
            model.log?.write("unlocked")
        }
    }

    private var setup: some View {
        @Bindable var model = model
        return NavigationStack {
            Form {
                Section("PROTOTYPE: run") {
                    Picker("Preset", selection: $model.config.preset) {
                        ForEach(Preset.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Picker("Keep-alive", selection: $model.config.keepAlive) {
                        ForEach(KeepAlive.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Picker("Dip", selection: $model.config.dip) {
                        ForEach(DipMode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Toggle("Compensate outputLatency", isOn: $model.config.compensateLatency)
                    Toggle("1 s heartbeat (can hide lateness)", isOn: $model.config.heartbeat)
                    TextField("Note: e.g. locked, Spotify", text: $model.config.note)
                }
                Section {
                    Button(model.bank == nil ? "Rendering Cues..." : "Start") { model.start() }
                        .disabled(model.bank == nil)
                    if let bank = model.bank {
                        LabeledContent(
                            "Cues rendered",
                            value: "\(bank.buffers.count) of \(CueRenderer.words.count)")
                    }
                }
                Section("Logs") {
                    ForEach(model.logs, id: \.self) { url in
                        ShareLink(item: url) { Text(url.lastPathComponent).font(.caption) }
                    }
                }
            }
            .navigationTitle("Timing Probe")
        }
    }
}

struct RunningView: View {
    let model: ProbeModel
    let log: RunLog

    var body: some View {
        TimelineView(.animation) { _ in
            let state = log.snapshot()
            VStack(spacing: 16) {
                Text(state.finished ? "Finished" : state.phase).font(.largeTitle.bold())
                Text(
                    state.paused
                        ? "Paused" : "\(Int(RunLog.seconds(state.remaining).rounded(.up))) s"
                )
                .font(.system(size: 72, weight: .bold, design: .monospaced))
                Grid(alignment: .leading) {
                    GridRow {
                        Text("Worst Phase late")
                        Text(state.worstPhaseLateMs, format: .number.precision(.fractionLength(1)))
                        Text("ms")
                    }
                    GridRow {
                        Text("Worst Cue error")
                        Text(state.worstOnsetErrorMs, format: .number.precision(.fractionLength(1)))
                        Text("ms")
                    }
                    GridRow {
                        Text("Cues skipped")
                        Text("\(state.cuesSkipped)")
                    }
                    GridRow {
                        Text("Last event")
                        Text(state.lastEvent)
                    }
                }
                .font(.body.monospacedDigit())
                if state.finished {
                    Button("Done") { model.clear() }.buttonStyle(.borderedProminent)
                } else {
                    HStack(spacing: 24) {
                        Button(model.paused ? "Resume" : "Pause") {
                            model.paused.toggle()
                            let paused = model.paused
                            let probe = model.probe
                            Task {
                                if paused { await probe?.pause() } else { await probe?.resume() }
                            }
                        }
                        Button("Stop", role: .destructive) {
                            let probe = model.probe
                            Task { await probe?.stop() }
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Visible marker for filming a Phase change against the sound of its Cue.
            .background(state.phaseChanges % 2 == 0 ? Color.yellow : Color.cyan)
        }
    }
}
