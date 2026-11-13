import SwiftUI

struct SettingsScreen: View {
    @Bindable var remembered: RememberedValues
    let health: HealthSaves

    @Environment(\.colorSchemeContrast) private var contrast

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    var body: some View {
        let colors = InkColors(contrast: contrast)

        Form {
            Section {
                Toggle("Dip", isOn: $remembered.isDipOn)
                    .tint(colors.accent)
                    .listRowBackground(colors.raised)
            } header: {
                Text("Music").foregroundStyle(colors.secondary)
            } footer: {
                Text("Lowers other audio while a Cue speaks. Music never pauses.")
                    .foregroundStyle(colors.secondary)
            }
            AppleHealthSection(health: health, colors: colors)
            Section {
                LabeledContent("Version", value: version)
                    .listRowBackground(colors.raised)
            } header: {
                Text("About").foregroundStyle(colors.secondary)
            } footer: {
                // A footer rather than a row, since a row of its own read as something to tap.
                Text("Temper keeps everything on this device, and uses Apple Health only if you allow it.")
                    .foregroundStyle(colors.secondary)
            }
            #if DEBUG
                TimingLogsSection(colors: colors)
            #endif
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .foregroundStyle(colors.text)
        .background(colors.background.ignoresSafeArea())
        .navigationTitle("Settings")
    }
}
