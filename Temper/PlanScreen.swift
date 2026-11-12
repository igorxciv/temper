import SwiftUI
import TemperCore

/// A Workout Type's Plan on the board, where its values are changed and its Workout Starts. Each line opens its
/// value, and the Presets menu picks, saves and manages the type's Presets.
///
/// Has to fit on the iPhone SE, 375 by 667 pt, with Start and a Preset's subtitle, at every text size.
struct PlanScreen: View {
    let workoutType: WorkoutType
    let remembered: RememberedValues
    let start: (WorkoutType, Workout) -> Void

    @State private var editing: WorkoutValue?
    @State private var isNamingPreset = false
    @State private var isManagingPresets = false

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let ink = BoardInk(contrast: contrast)
        let settings = remembered[workoutType]
        let presets = remembered.presets(of: workoutType)
        let workout = workoutType.makeWorkout(from: settings)
        let board = PlanBoard(workoutType: workoutType, settings: settings)

        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 20) {
                PlanBoardView(board: board) { value in
                    editing = value
                }
                VStack(alignment: .leading, spacing: 4) {
                    if let note = board.note {
                        Text(note)
                    }
                    Text("Tap a line to change it.")
                }
                .font(.subheadline)
                .foregroundStyle(ink.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaBar(edge: .bottom) {
            StartButton(workout: workout) {
                start(workoutType, workout)
            }
        }
        // The name sheet's keyboard would otherwise squeeze the board behind the sheet.
        .ignoresSafeArea(.keyboard)
        .background(ink.ground.ignoresSafeArea())
        .navigationTitle(workoutType.title)
        // An empty subtitle draws nothing. VoiceOver reads it after the title, and its text spells out the state.
        .navigationSubtitle(presets.subtitle(for: settings) ?? "")
        .navigationBarTitleDisplayMode(.inline)
        // In the title as well as the toolbar, so a Preset is two taps away between sets either way.
        .toolbarTitleMenu {
            presetMenu(presets, settings: settings)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu("Presets", systemImage: "bookmark") {
                    presetMenu(presets, settings: settings)
                }
            }
        }
        .sheet(item: $editing) { value in
            ValueSheet(value: value, amount: settings[value]) { draft in
                remembered[workoutType][value] = draft
            }
        }
        .sheet(isPresented: $isNamingPreset) {
            PresetNameSheet(title: "New Preset") { name in
                remembered.presets(of: workoutType).nameProblem(name)
            } save: { name throws(PresetNameProblem) in
                try remembered.saveAsNewPreset(named: name, of: workoutType)
            }
        }
        .sheet(isPresented: $isManagingPresets) {
            ManagePresetsSheet(workoutType: workoutType, remembered: remembered)
        }
    }

    private func presetMenu(_ presets: PresetList, settings: WorkoutSettings) -> some View {
        PresetMenu(list: presets, isModified: presets.isModified(settings)) { id in
            remembered.pickPreset(id, of: workoutType)
        } saveAsNew: {
            isNamingPreset = true
        } update: {
            remembered.updatePickedPreset(of: workoutType)
        } manage: {
            isManagingPresets = true
        }
    }
}
