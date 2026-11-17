import SwiftUI
import UIKit

struct SettingsScreen: View {
    let health: HealthAccess
    @Bindable var musicLowering: MusicLowering

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
                Text("Other apps' audio dips while a Cue is spoken, and comes back up after. The gongs leave it alone.")
                    .foregroundStyle(colors.secondary)
            }
            AppleWatchSection(health: health, colors: colors)
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
