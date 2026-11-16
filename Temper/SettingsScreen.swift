import SwiftUI

struct SettingsScreen: View {
    let health: HealthAccess

    @Environment(\.colorSchemeContrast) private var contrast

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    var body: some View {
        let colors = InkColors(contrast: contrast)

        Form {
            AppleWatchSection(health: health, colors: colors)
            Section {
                LabeledContent("Version", value: version)
                    .listRowBackground(colors.raised)
            } header: {
                Text("About").foregroundStyle(colors.secondary)
            } footer: {
                // A footer rather than a row, since a row of its own read as something to tap.
                Text("Temper keeps everything on this device, and saves nothing to Apple Health.")
                    .foregroundStyle(colors.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .foregroundStyle(colors.text)
        .background(colors.background.ignoresSafeArea())
        .navigationTitle("Settings")
    }
}
