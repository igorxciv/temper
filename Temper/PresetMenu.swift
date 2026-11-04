import SwiftUI
import TemperCore

/// The title menu: the type's Presets in order, then what can be done with them.
struct PresetMenu: View {
    let list: PresetList
    let isModified: Bool
    let pick: (Preset.ID) -> Void
    let saveAsNew: () -> Void
    let update: () -> Void
    let manage: () -> Void

    var body: some View {
        // Plain buttons rather than a Picker, so choosing the picked Preset again still reaches pick. Picking
        // replaces setup's values without asking, since they're only ever a scratch copy of a Preset.
        ForEach(list.presets) { preset in
            let isPicked = preset.id == list.pickedID

            Button {
                pick(preset.id)
            } label: {
                if isPicked {
                    Label(preset.name, systemImage: "checkmark")
                } else {
                    Text(preset.name)
                }
            }
            .accessibilityAddTraits(isPicked ? .isSelected : [])
        }
        if !list.presets.isEmpty {
            Divider()
        }
        Button("Save as New Preset…", systemImage: "plus", action: saveAsNew)
        // No confirmation, because the label names the Preset it overwrites.
        if isModified, let picked = list.picked {
            Button("Update “\(picked.name)”", systemImage: "arrow.triangle.2.circlepath", action: update)
        }
        if !list.presets.isEmpty {
            Button("Manage Presets…", systemImage: "list.bullet", action: manage)
        }
    }
}
