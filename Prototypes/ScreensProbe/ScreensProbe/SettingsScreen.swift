// PROTOTYPE, throw away. Settings has one design: it holds a single option, so variants would be noise.
import SwiftUI

struct SettingsScreen: View {
    @Bindable var state: ProbeState

    var body: some View {
        Form {
            Section {
                Toggle("Dip", isOn: $state.dip)
            } header: {
                Text("Music")
            } footer: {
                Text("Lowers other audio while a Cue speaks. Music never pauses.")
            }
            Section("About") {
                LabeledContent("Version", value: "0.1")
                Text("Temper keeps everything on this device.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
    }
}
