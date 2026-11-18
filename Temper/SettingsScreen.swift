import SwiftUI
import UIKit

/// Settings on one screen: the Workout settings in one group, each row explaining itself in a one-line subtitle
/// rather than a footer, then the Leave a Tip button and the two links out.
struct SettingsScreen: View {
    let health: HealthAccess
    @Bindable var musicLowering: MusicLowering
    @Bindable var secondsWheel: SecondsWheel
    let roundSound: RoundSoundSetting
    let tipJar: TipJar

    @State private var showsTipJar = false
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.scenePhase) private var scenePhase

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    private var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
    }

    var body: some View {
        let colors = InkColors(contrast: contrast)

        Form {
            Section {
                NavigationLink {
                    RoundSoundScreen(roundSound: roundSound)
                } label: {
                    LabeledContent {
                        Text(roundSound.sound.name).foregroundStyle(colors.secondary)
                    } label: {
                        Label("Round Sound", systemImage: "bell")
                    }
                }
                Toggle(isOn: $musicLowering.isOn) {
                    Label {
                        Text("Lower Other Audio")
                        Text("Music dips while Temper speaks").foregroundStyle(colors.secondary)
                    } icon: {
                        Image(systemName: "speaker.wave.1")
                    }
                }
                Toggle(isOn: $secondsWheel.offersEverySecond) {
                    Label {
                        Text("Set to the Second")
                        Text("Seconds step by 1, not 5").foregroundStyle(colors.secondary)
                    } icon: {
                        Image(systemName: "dial.low")
                    }
                }
                // No row on a device without Health.
                if let row = health.row {
                    HeartRateSetting(row: row, colors: colors) {
                        Task { await health.requestPermission() }
                    }
                }
            } header: {
                Text("Workout").foregroundStyle(colors.secondary)
            }
            .listRowBackground(colors.raised)

            Section {
                VStack(spacing: 12) {
                    Text("Temper is free, with no ads.")
                        .font(.subheadline)
                        .foregroundStyle(colors.secondary)
                    Button("Leave a Tip", systemImage: "heart.fill") { showsTipJar = true }
                        .buttonStyle(.glassProminent)
                        .tint(colors.accent)
                        .foregroundStyle(colors.onAccent)
                }
                .frame(maxWidth: .infinity)
            }
            .listRowBackground(Color.clear)

            Section {
                if let privacyPolicy = SupportLinks.privacyPolicy {
                    Link(destination: privacyPolicy) {
                        LinkLabel(title: "Privacy Policy", systemImage: "hand.raised", colors: colors)
                    }
                }
                if let email = SupportLinks.email(
                    version: version, build: build, systemVersion: UIDevice.current.systemVersion)
                {
                    Link(destination: email) {
                        LinkLabel(title: "Contact Support", systemImage: "envelope", colors: colors)
                    }
                }
            } footer: {
                // A footer rather than rows, since a row of its own read as something to tap.
                Text("Temper \(version) · Everything stays on this device.")
                    .foregroundStyle(colors.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }
            .listRowBackground(colors.raised)
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .foregroundStyle(colors.text)
        .tint(colors.accent)
        .labelIconToTitleSpacing(14)
        .background(colors.background.ignoresSafeArea())
        .navigationTitle("Settings")
        .sheet(isPresented: $showsTipJar) {
            TipJarSheet(tipJar: tipJar)
        }
        #if DEBUG
            .onAppear {
                if DebugLaunch.tipCelebration != nil { showsTipJar = true }
            }
        #endif
        .task(id: scenePhase) {
            if scenePhase == .active {
                await health.refreshStatus()
            }
        }
    }
}

/// A row that leaves Temper, for Safari or Mail, marked with an arrow out so it doesn't read as a screen of its own.
private struct LinkLabel: View {
    let title: String
    let systemImage: String
    let colors: InkColors

    var body: some View {
        LabeledContent {
            Image(systemName: "arrow.up.right")
                .foregroundStyle(colors.secondary)
                .accessibilityHidden(true)
        } label: {
            Label(title, systemImage: systemImage).foregroundStyle(colors.text)
        }
    }
}
