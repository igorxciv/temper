import SwiftUI
import UIKit

struct SettingsScreen: View {
    let health: HealthAccess
    @Bindable var musicLowering: MusicLowering
    let roundSound: RoundSoundSetting
    let tipJar: TipJar

    @State private var preview = RoundSoundPreview()
    @Environment(\.colorSchemeContrast) private var contrast

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
                Toggle("Lower music when Temper speaks", isOn: $musicLowering.isOn)
                    .listRowBackground(colors.raised)
            } header: {
                Text("Sound").foregroundStyle(colors.secondary)
            } footer: {
                Text(
                    "Other apps' audio dips while Temper speaks, and comes back up after. A round sound on its own leaves it alone."
                )
                .foregroundStyle(colors.secondary)
            }
            Section {
                ForEach(RoundSound.allCases, id: \.self) { sound in
                    RoundSoundRow(sound: sound, isChosen: sound == roundSound.sound, colors: colors) {
                        roundSound.sound = sound
                        preview.play(sound)
                    }
                }
                .listRowBackground(colors.raised)
            } header: {
                Text("Round Sound").foregroundStyle(colors.secondary)
            } footer: {
                Text(
                    "Starts and ends every round, and plays under “Cooldown” and “Workout complete”. Tap one to hear it."
                )
                .foregroundStyle(colors.secondary)
            }
            AppleWatchSection(health: health, colors: colors)
            TipJarSection(tipJar: tipJar, colors: colors)
            Section {
                LabeledContent("Version", value: version)
                if let privacyPolicy = SupportLinks.privacyPolicy {
                    Link(destination: privacyPolicy) {
                        LinkLabel(title: "Privacy Policy", colors: colors)
                    }
                }
                if let email = SupportLinks.email(
                    version: version, build: build, systemVersion: UIDevice.current.systemVersion)
                {
                    Link(destination: email) {
                        LinkLabel(title: "Contact Support", colors: colors)
                    }
                }
            } header: {
                Text("About").foregroundStyle(colors.secondary)
            } footer: {
                // A footer rather than a row, since a row of its own read as something to tap.
                Text("Temper keeps everything on this device, and saves nothing to Apple Health.")
                    .foregroundStyle(colors.secondary)
            }
            .listRowBackground(colors.raised)
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .foregroundStyle(colors.text)
        .background(colors.background.ignoresSafeArea())
        .navigationTitle("Settings")
    }
}

/// A Round Sound to pick, ticked if it's the one chosen. Tapping it picks it and plays it, even if it's already chosen,
/// so the owner can hear it again.
private struct RoundSoundRow: View {
    let sound: RoundSound
    let isChosen: Bool
    let colors: InkColors
    let choose: () -> Void

    var body: some View {
        Button(action: choose) {
            LabeledContent {
                if isChosen {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(colors.accent)
                        .accessibilityHidden(true)
                }
            } label: {
                Text(sound.name).foregroundStyle(colors.text)
            }
            .contentShape(.rect)
        }
        .accessibilityAddTraits(isChosen ? .isSelected : [])
        .accessibilityHint("Plays the sound")
    }
}

/// A row that leaves Temper, for Safari or Mail, marked with an arrow out so it doesn't read as a screen of its own.
private struct LinkLabel: View {
    let title: String
    let colors: InkColors

    var body: some View {
        LabeledContent {
            Image(systemName: "arrow.up.right")
                .foregroundStyle(colors.secondary)
                .accessibilityHidden(true)
        } label: {
            Text(title).foregroundStyle(colors.text)
        }
    }
}
