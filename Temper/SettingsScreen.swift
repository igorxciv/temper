import SwiftUI

/// Temper's few settings, written on the board in a native grouped form: white rows on the board's ground, each
/// section headed in black marker.
struct SettingsScreen: View {
    @Bindable var remembered: RememberedValues
    let health: HealthSaves

    @Environment(\.colorSchemeContrast) private var contrast

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    var body: some View {
        let ink = BoardInk(contrast: contrast)

        Form {
            Section {
                Toggle("Dip", isOn: $remembered.isDipOn)
                    .tint(ink.marker)
                    .listRowBackground(ink.row)
            } header: {
                Text("Music").foregroundStyle(ink.marker)
            } footer: {
                Text("Lowers other audio while a Cue speaks. Music never pauses.")
                    .foregroundStyle(ink.secondary)
            }
            AppleHealthSection(health: health, ink: ink)
            Section {
                LabeledContent("Version", value: version)
                    .listRowBackground(ink.row)
            } header: {
                Text("About").foregroundStyle(ink.marker)
            } footer: {
                // A footer rather than a row, since a row of its own read as something to tap.
                Text("Temper keeps everything on this device, and uses Apple Health only if you allow it.")
                    .foregroundStyle(ink.secondary)
            }
            #if DEBUG
                TimingLogsSection(ink: ink)
            #endif
        }
        .formStyle(.grouped)
        // Title-style headers, as the system's settings layout has them, rather than small captions.
        .headerProminence(.increased)
        .scrollContentBackground(.hidden)
        .foregroundStyle(ink.marker)
        .background(ink.ground.ignoresSafeArea())
        .navigationTitle("Settings")
    }
}
