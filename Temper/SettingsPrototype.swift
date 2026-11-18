#if DEBUG
    // PROTOTYPE, throwaway. Answers "how should Settings be organised?" with four variants on the real Settings tab,
    // switchable from the floating pill or at launch with `-settingsVariant now|a|b|c`. Every variant drives the real
    // settings objects. Where the Simulator has no tips or Health status, rows marked "(stub)" stand in so each layout
    // is judged at its real density. Delete this file and its hook in TemperApp once a variant wins.
    import SwiftUI
    import UIKit

    enum SettingsVariant: String, CaseIterable {
        case now, a, b, c

        var title: String {
            switch self {
            case .now: "Now (today's screen)"
            case .a: "A · Drill-down"
            case .b: "B · One tidy list"
            case .c: "C · Header card"
            }
        }
    }

    struct SettingsPrototype: View {
        let health: HealthAccess
        let musicLowering: MusicLowering
        let secondsWheel: SecondsWheel
        let roundSound: RoundSoundSetting
        let tipJar: TipJar

        @State private var variant =
            SettingsVariant(rawValue: UserDefaults.standard.string(forKey: "settingsVariant") ?? "") ?? .a

        var body: some View {
            NavigationStack {
                switch variant {
                case .now:
                    SettingsScreen(
                        health: health, musicLowering: musicLowering, secondsWheel: secondsWheel,
                        roundSound: roundSound, tipJar: tipJar)
                case .a:
                    DrillDownSettings(
                        health: health, musicLowering: musicLowering, secondsWheel: secondsWheel,
                        roundSound: roundSound, tipJar: tipJar)
                case .b:
                    TidyListSettings(
                        health: health, musicLowering: musicLowering, secondsWheel: secondsWheel,
                        roundSound: roundSound, tipJar: tipJar)
                case .c:
                    HeaderCardSettings(
                        health: health, musicLowering: musicLowering, secondsWheel: secondsWheel,
                        roundSound: roundSound, tipJar: tipJar)
                }
            }
            .id(variant)
            .overlay(alignment: .bottom) { switcher }
        }

        private var switcher: some View {
            HStack(spacing: 16) {
                Button("Previous variant", systemImage: "chevron.left") { step(-1) }
                Text(variant.title).font(.subheadline.weight(.semibold)).monospacedDigit()
                Button("Next variant", systemImage: "chevron.right") { step(1) }
            }
            .labelStyle(.iconOnly)
            .foregroundStyle(.black)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.white, in: .capsule)
            .shadow(radius: 8)
            .padding(.bottom, 8)
        }

        private func step(_ offset: Int) {
            let all = SettingsVariant.allCases
            let index = all.firstIndex(of: variant) ?? 0
            variant = all[(index + offset + all.count) % all.count]
        }
    }

    // MARK: - Shared bits (data and plain rows only; each variant owns its own layout)

    private enum Stub {
        static let tips = [
            Tip(id: "stub.small", name: "Small Tip (stub)", price: "$0.99"),
            Tip(id: "stub.medium", name: "Medium Tip (stub)", price: "$2.99"),
            Tip(id: "stub.large", name: "Large Tip (stub)", price: "$4.99"),
        ]
    }

    extension TipJar {
        fileprivate var shownTips: (tips: [Tip], isStub: Bool) {
            if case .ready(let tips) = shelf, !tips.isEmpty { (tips, false) } else { (Stub.tips, true) }
        }
    }

    private enum AppInfo {
        static var version: String {
            Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        }
        static var build: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "" }
        static var email: URL? {
            SupportLinks.email(version: version, build: build, systemVersion: UIDevice.current.systemVersion)
        }
    }

    /// An iOS Settings-style icon: a white glyph on a tinted rounded square.
    private struct TileIcon: View {
        let symbol: String
        let tint: Color

        var body: some View {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(tint.gradient, in: .rect(cornerRadius: 8))
        }
    }

    private struct OutLink: View {
        let title: String
        let symbol: String?
        let url: URL?
        let colors: InkColors

        var body: some View {
            if let url {
                Link(destination: url) {
                    LabeledContent {
                        Image(systemName: "arrow.up.right").foregroundStyle(colors.secondary)
                    } label: {
                        if let symbol {
                            Label(title, systemImage: symbol).foregroundStyle(colors.text)
                        } else {
                            Text(title).foregroundStyle(colors.text)
                        }
                    }
                }
            }
        }
    }

    private struct HeartRateValue: View {
        let health: HealthAccess
        let colors: InkColors

        var body: some View {
            switch health.row {
            case .allowed?: Text("Allowed").foregroundStyle(colors.secondary)
            case .notAllowed?: Text("Not Allowed").foregroundStyle(colors.secondary)
            case .allowHeartRate?, nil:
                Button("Allow") { Task { await health.requestPermission() } }
                    .foregroundStyle(colors.accent)
            }
        }
    }

    extension View {
        fileprivate func inkForm(_ colors: InkColors) -> some View {
            formStyle(.grouped)
                .scrollContentBackground(.hidden)
                .foregroundStyle(colors.text)
                .background(colors.background.ignoresSafeArea())
                .contentMargins(.bottom, 64, for: .scrollContent)  // room for the prototype pill
        }
    }

    // MARK: - A · Drill-down (the iOS Settings app pattern)

    /// A short top level of icon rows, each showing its current value, and one screen per topic underneath. The top
    /// level has no footers at all; the explanations live on the pages they explain.
    private struct DrillDownSettings: View {
        let health: HealthAccess
        @Bindable var musicLowering: MusicLowering
        @Bindable var secondsWheel: SecondsWheel
        let roundSound: RoundSoundSetting
        let tipJar: TipJar

        @Environment(\.colorSchemeContrast) private var contrast

        var body: some View {
            let colors = InkColors(contrast: contrast)
            Form {
                Group {
                    Section {
                        NavigationLink {
                            SoundPage(musicLowering: musicLowering, roundSound: roundSound)
                        } label: {
                            LabeledContent {
                                Text(roundSound.sound.name)
                            } label: {
                                Label {
                                    Text("Sound")
                                } icon: {
                                    TileIcon(symbol: "speaker.wave.2.fill", tint: .pink)
                                }
                            }
                        }
                        NavigationLink {
                            TimesPage(secondsWheel: secondsWheel)
                        } label: {
                            LabeledContent {
                                Text(secondsWheel.offersEverySecond ? "Every second" : "5-second steps")
                            } label: {
                                Label {
                                    Text("Setting Times")
                                } icon: {
                                    TileIcon(symbol: "timer", tint: .orange)
                                }
                            }
                        }
                        NavigationLink {
                            AppleWatchPage(health: health)
                        } label: {
                            LabeledContent {
                                Text(watchSummary)
                            } label: {
                                Label {
                                    Text("Apple Watch")
                                } icon: {
                                    TileIcon(symbol: "applewatch", tint: .green)
                                }
                            }
                        }
                    }
                    Section {
                        NavigationLink {
                            TipsPage(tipJar: tipJar)
                        } label: {
                            Label {
                                Text("Support Temper")
                            } icon: {
                                TileIcon(symbol: "heart.fill", tint: .red)
                            }
                        }
                        NavigationLink {
                            AboutPage()
                        } label: {
                            Label {
                                Text("About")
                            } icon: {
                                TileIcon(symbol: "info", tint: .gray)
                            }
                        }
                    }
                }
                .listRowBackground(colors.raised)
            }
            .inkForm(colors)
            .navigationTitle("Settings")
        }

        private var watchSummary: String {
            switch health.row {
            case .allowed?: "Heart rate on"
            case .notAllowed?: "Not allowed"
            case .allowHeartRate?, nil: "Set up"
            }
        }
    }

    /// The Round Sound list sits right on this page, so picking one is a level shallower than today.
    private struct SoundPage: View {
        @Bindable var musicLowering: MusicLowering
        let roundSound: RoundSoundSetting

        @State private var preview = RoundSoundPreview()
        @Environment(\.colorSchemeContrast) private var contrast

        var body: some View {
            let colors = InkColors(contrast: contrast)
            Form {
                Group {
                    Section {
                        ForEach(RoundSound.allCases, id: \.self) { sound in
                            Button {
                                roundSound.sound = sound
                                preview.play(sound)
                            } label: {
                                LabeledContent {
                                    if sound == roundSound.sound {
                                        Image(systemName: "checkmark").fontWeight(.semibold).foregroundStyle(
                                            colors.accent)
                                    }
                                } label: {
                                    Text(sound.name).foregroundStyle(colors.text)
                                }
                                .contentShape(.rect)
                            }
                        }
                    } header: {
                        Text("Round Sound")
                    } footer: {
                        Text("Starts and ends every Round. Tap one to hear it.")
                    }
                    Section {
                        Toggle("Lower Other Audio", isOn: $musicLowering.isOn)
                    } footer: {
                        Text("Music and podcasts dip while Temper speaks, then come back up.")
                    }
                }
                .listRowBackground(colors.raised)
            }
            .inkForm(colors)
            .navigationTitle("Sound")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private struct TimesPage: View {
        @Bindable var secondsWheel: SecondsWheel
        @Environment(\.colorSchemeContrast) private var contrast

        var body: some View {
            let colors = InkColors(contrast: contrast)
            Form {
                Group {
                    Section {
                        Toggle("Set to the Second", isOn: $secondsWheel.offersEverySecond)
                    } footer: {
                        Text("The seconds wheel steps by 1 instead of 5.")
                    }
                }
                .listRowBackground(colors.raised)
            }
            .inkForm(colors)
            .navigationTitle("Setting Times")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private struct AppleWatchPage: View {
        let health: HealthAccess
        @Environment(\.colorSchemeContrast) private var contrast

        var body: some View {
            let colors = InkColors(contrast: contrast)
            Form {
                Group {
                    Section {
                        LabeledContent("Heart Rate" + (health.row == nil ? " (stub)" : "")) {
                            HeartRateValue(health: health, colors: colors)
                        }
                    } footer: {
                        Text((health.row ?? .allowHeartRate).footer)
                    }
                }
                .listRowBackground(colors.raised)
            }
            .inkForm(colors)
            .navigationTitle("Apple Watch")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private struct TipsPage: View {
        let tipJar: TipJar
        @Environment(\.colorSchemeContrast) private var contrast

        var body: some View {
            let colors = InkColors(contrast: contrast)
            let shown = tipJar.shownTips
            Form {
                Group {
                    Section {
                        ForEach(shown.tips) { tip in
                            Button {
                                Task { await tipJar.tip(tip.id) }
                            } label: {
                                LabeledContent {
                                    Text(tip.price).foregroundStyle(colors.text)
                                } label: {
                                    Text(tip.name).foregroundStyle(colors.accent)
                                }
                            }
                            .disabled(shown.isStub || tipJar.purchasing != nil)
                        }
                    } footer: {
                        Text("Temper is free and has no ads. Tips keep it on the App Store, and unlock nothing.")
                    }
                }
                .listRowBackground(colors.raised)
            }
            .inkForm(colors)
            .navigationTitle("Support Temper")
            .navigationBarTitleDisplayMode(.inline)
            .task { await tipJar.load() }
        }
    }

    private struct AboutPage: View {
        @Environment(\.colorSchemeContrast) private var contrast

        var body: some View {
            let colors = InkColors(contrast: contrast)
            Form {
                Group {
                    Section {
                        LabeledContent("Version", value: AppInfo.version)
                    } footer: {
                        Text("Temper keeps everything on this device.")
                    }
                    Section {
                        OutLink(title: "Privacy Policy", symbol: nil, url: SupportLinks.privacyPolicy, colors: colors)
                        OutLink(title: "Contact Support", symbol: nil, url: AppInfo.email, colors: colors)
                    }
                }
                .listRowBackground(colors.raised)
            }
            .inkForm(colors)
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - B · One tidy list

    /// Everything on one screen, but quieter: the settings merge into one Workout group, each row explains itself in a
    /// one-line subtitle instead of a footer, tips are one compact row of price buttons, and About shrinks to two
    /// links and a closing line.
    private struct TidyListSettings: View {
        let health: HealthAccess
        @Bindable var musicLowering: MusicLowering
        @Bindable var secondsWheel: SecondsWheel
        let roundSound: RoundSoundSetting
        let tipJar: TipJar

        @Environment(\.colorSchemeContrast) private var contrast

        var body: some View {
            let colors = InkColors(contrast: contrast)
            let shown = tipJar.shownTips
            Form {
                Group {
                    Section("Workout") {
                        NavigationLink {
                            RoundSoundScreen(roundSound: roundSound)
                        } label: {
                            LabeledContent {
                                Text(roundSound.sound.name)
                            } label: {
                                Label("Round Sound", systemImage: "bell")
                            }
                        }
                        Toggle(isOn: $musicLowering.isOn) {
                            Label {
                                Text("Lower Other Audio")
                                Text("Music dips while Temper speaks")
                            } icon: {
                                Image(systemName: "speaker.wave.1")
                            }
                        }
                        Toggle(isOn: $secondsWheel.offersEverySecond) {
                            Label {
                                Text("Set to the Second")
                                Text("Seconds step by 1, not 5")
                            } icon: {
                                Image(systemName: "dial.low")
                            }
                        }
                        LabeledContent {
                            HeartRateValue(health: health, colors: colors)
                        } label: {
                            Label {
                                Text("Heart Rate" + (health.row == nil ? " (stub)" : ""))
                                Text("Shown on Apple Watch")
                            } icon: {
                                Image(systemName: "heart")
                            }
                        }
                    }
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Temper is free, with no ads. A tip keeps it on the App Store.")
                                .font(.subheadline)
                                .foregroundStyle(colors.secondary)
                            HStack {
                                ForEach(shown.tips) { tip in
                                    Button(tip.price) { Task { await tipJar.tip(tip.id) } }
                                        .buttonStyle(.glass)
                                        .frame(maxWidth: .infinity)
                                        .disabled(shown.isStub || tipJar.purchasing != nil)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    } header: {
                        Text("Leave a Tip" + (shown.isStub ? " (stub)" : ""))
                    }
                    Section {
                        OutLink(
                            title: "Privacy Policy", symbol: "hand.raised", url: SupportLinks.privacyPolicy,
                            colors: colors)
                        OutLink(title: "Contact Support", symbol: "envelope", url: AppInfo.email, colors: colors)
                    } footer: {
                        Text("Temper \(AppInfo.version) · Everything stays on this device.")
                            .frame(maxWidth: .infinity)
                            .padding(.top, 8)
                    }
                }
                .listRowBackground(colors.raised)
            }
            .symbolRenderingMode(.monochrome)
            .labelIconToTitleSpacing(14)
            .tint(colors.accent)
            .inkForm(colors)
            .navigationTitle("Settings")
        }
    }

    // MARK: - C · Header card

    /// The list holds only settings. Who Temper is, and the tip, sit in a card at the top; tips open in a sheet; the
    /// version, privacy policy and support move into an info menu in the toolbar.
    private struct HeaderCardSettings: View {
        let health: HealthAccess
        @Bindable var musicLowering: MusicLowering
        @Bindable var secondsWheel: SecondsWheel
        let roundSound: RoundSoundSetting
        let tipJar: TipJar

        @State private var showsTips = false
        @Environment(\.colorSchemeContrast) private var contrast

        var body: some View {
            let colors = InkColors(contrast: contrast)
            Form {
                Section {
                    VStack(spacing: 10) {
                        Image(systemName: "timer")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(colors.onAccent)
                            .frame(width: 64, height: 64)
                            .background(colors.accent.gradient, in: .rect(cornerRadius: 16))
                        Text("Temper").font(.title2.bold())
                        Text("Free, no ads, and everything stays on this device.")
                            .font(.subheadline)
                            .foregroundStyle(colors.secondary)
                            .multilineTextAlignment(.center)
                        Button("Leave a Tip", systemImage: "heart.fill") { showsTips = true }
                            .buttonStyle(.glassProminent)
                            .tint(colors.accent)
                            .foregroundStyle(colors.onAccent)
                            .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.clear)

                Section {
                    NavigationLink {
                        RoundSoundScreen(roundSound: roundSound)
                    } label: {
                        LabeledContent("Round Sound") { Text(roundSound.sound.name) }
                    }
                    Toggle("Lower Other Audio", isOn: $musicLowering.isOn)
                } header: {
                    Text("Sound")
                } footer: {
                    Text("Music dips while Temper speaks.")
                }
                .listRowBackground(colors.raised)

                Section {
                    Toggle("Set to the Second", isOn: $secondsWheel.offersEverySecond)
                } header: {
                    Text("Wheels")
                } footer: {
                    Text("Seconds step by 1 instead of 5.")
                }
                .listRowBackground(colors.raised)

                Section {
                    LabeledContent("Heart Rate" + (health.row == nil ? " (stub)" : "")) {
                        HeartRateValue(health: health, colors: colors)
                    }
                } header: {
                    Text("Apple Watch")
                } footer: {
                    Text("Shows your heart rate and Zone. Nothing is saved to Health.")
                }
                .listRowBackground(colors.raised)
            }
            .inkForm(colors)
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu("About", systemImage: "info.circle") {
                        Section("Temper \(AppInfo.version)") {
                            if let url = SupportLinks.privacyPolicy {
                                Link(destination: url) { Label("Privacy Policy", systemImage: "hand.raised") }
                            }
                            if let url = AppInfo.email {
                                Link(destination: url) { Label("Contact Support", systemImage: "envelope") }
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showsTips) {
                NavigationStack {
                    TipsPage(tipJar: tipJar)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done", systemImage: "checkmark") { showsTips = false }
                            }
                        }
                }
                .presentationDetents([.medium])
            }
        }
    }
#endif
