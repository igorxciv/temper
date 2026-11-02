// PROTOTYPE, throw away. Settings has one design: it holds a single option, so variants would be noise.
import SwiftUI

struct SettingsScreen: View {
    @Bindable var state: ProbeState

    private var colors: ThemeColors { state.theme.colors }

    var body: some View {
        Form {
            Section {
                Toggle("Dip", isOn: $state.dip)
                    .tint(colors.accent)
                    .listRowBackground(colors.raised)
            } header: {
                Text("Music").foregroundStyle(colors.secondary)
            } footer: {
                Text("Lowers other audio while a Cue speaks. Music never pauses.")
                    .foregroundStyle(colors.secondary)
            }
            Section {
                LabeledContent("Version", value: "0.1")
                    .listRowBackground(colors.raised)
                Text("Temper keeps everything on this device.")
                    .listRowBackground(colors.raised)
            } header: {
                Text("About").foregroundStyle(colors.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .foregroundStyle(colors.text)
        .background(colors.background.ignoresSafeArea())
        .navigationTitle("Settings")
    }
}
