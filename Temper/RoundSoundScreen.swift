import SwiftUI

/// The Round Sounds to pick from, a screen of their own under Settings so six rows don't crowd the rest of it.
/// Tapping one picks it and plays it, even if it's already chosen, so the owner can hear it again.
struct RoundSoundScreen: View {
    let roundSound: RoundSoundSetting

    @State private var preview = RoundSoundPreview()
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let colors = InkColors(contrast: contrast)

        Form {
            Section {
                ForEach(RoundSound.allCases, id: \.self) { sound in
                    RoundSoundRow(sound: sound, isChosen: sound == roundSound.sound, colors: colors) {
                        roundSound.sound = sound
                        preview.play(sound)
                    }
                }
                .listRowBackground(colors.raised)
            } footer: {
                Text(
                    "Starts and ends every Round, and plays under “Cooldown” and “Workout complete”. Tap one to hear it."
                )
                .foregroundStyle(colors.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .foregroundStyle(colors.text)
        .background(colors.background.ignoresSafeArea())
        .navigationTitle("Round Sound")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// A Round Sound to pick, ticked if it's the one chosen.
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
