import SwiftUI
import TemperCore

/// One Workout Type's Presets, to rename and delete. Tapping a row renames it rather than picking it, since
/// picking stays in the title menu. Each change saves at once, so Done only closes the sheet.
struct ManagePresetsSheet: View {
    let workoutType: WorkoutType
    let remembered: RememberedValues

    @State private var renaming: Preset?
    @State private var deleting: Preset?
    @State private var isConfirmingDelete = false
    @State private var editMode = EditMode.inactive

    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let colors = InkColors(contrast: contrast)
        let list = remembered.presets(of: workoutType)

        NavigationStack {
            List {
                ForEach(list.presets) { preset in
                    PresetRow(
                        name: preset.name,
                        summary: list.summary(of: preset),
                        isPicked: preset.id == list.pickedID
                    ) {
                        renaming = preset
                    }
                    .listRowBackground(colors.background)
                    .accessibilityAction(named: "Rename") {
                        renaming = preset
                    }
                    .accessibilityAction(named: "Delete") {
                        confirmDelete(preset)
                    }
                }
                // Swipe and edit mode's delete control both land here, and the row stays until it's confirmed.
                .onDelete { offsets in
                    if let index = offsets.first {
                        confirmDelete(list.presets[index])
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .overlay {
                if list.presets.isEmpty {
                    ContentUnavailableView {
                        Text("No Presets").foregroundStyle(colors.secondary)
                    }
                }
            }
            .confirmationDialog(
                "Delete “\(deleting?.name ?? "")”?",
                isPresented: $isConfirmingDelete,
                titleVisibility: .visible,
                presenting: deleting
            ) { preset in
                Button("Delete", role: .destructive) {
                    remembered.deletePreset(preset.id, of: workoutType)
                }
                Button("Cancel", role: .cancel) {}
            }
            .navigationTitle("\(workoutType.title) Presets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !list.presets.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        EditButton()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            // Here so the Edit button and the list share one edit mode, which ends once nothing is left to edit.
            .environment(\.editMode, $editMode)
        }
        .onChange(of: list.presets.isEmpty) { _, isEmpty in
            if isEmpty {
                editMode = .inactive
            }
        }
        .sheet(item: $renaming) { preset in
            PresetNameSheet(title: "Rename Preset", name: preset.name) { name in
                remembered.presets(of: workoutType).nameProblem(name, excluding: preset.id)
            } save: { name in
                // Save is enabled only once the name check passes, so this can't throw.
                try? remembered.renamePreset(preset.id, to: name, of: workoutType)
            }
        }
        .presentationDetents([.large])
        .presentationBackground(colors.raised)
    }

    private func confirmDelete(_ preset: Preset) {
        deleting = preset
        isConfirmingDelete = true
    }
}

/// A Preset's name over its value summary, with a checkmark when it's the picked one.
private struct PresetRow: View {
    let name: String
    let summary: String
    let isPicked: Bool
    let rename: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let colors = InkColors(contrast: contrast)

        Button(action: rename) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .foregroundStyle(colors.text)
                    Text(summary)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(colors.secondary)
                }
                Spacer()
                if isPicked {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(colors.accent)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(.rect)
        }
        .accessibilityAddTraits(isPicked ? .isSelected : [])
    }
}
