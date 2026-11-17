import SwiftUI
import TemperCore

/// Renames or clears one Work's Exercise on a described Plan, so a word dictation misheard is fixed without describing
/// the whole Plan again. Lengths and order stay as Describe wrote them.
struct ExerciseSheet: View {
    /// The Work being renamed, and its Exercise as the sheet opens.
    struct Renaming: Identifiable {
        let place: Plan.PhasePlace
        let name: String

        var id: Plan.PhasePlace { place }
    }

    let renaming: Renaming
    /// Called with the new name, which may be blank to clear it.
    let save: (String) -> Void

    @State private var name: String
    @FocusState private var isFocused: Bool
    @Environment(\.dismiss) private var dismiss

    init(renaming: Renaming, save: @escaping (String) -> Void) {
        self.renaming = renaming
        self.save = save
        _name = State(initialValue: renaming.name)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Exercise", text: $name)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .focused($isFocused)
                        .onSubmit(saveAndDismiss)
                        .onChange(of: name) {
                            if name.count > Exercise.maximumLength {
                                name = String(name.prefix(Exercise.maximumLength))
                            }
                        }
                } footer: {
                    Text("Leave it empty for a Work with no Exercise.")
                }
            }
            .navigationTitle("Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", role: .confirm, action: saveAndDismiss)
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear { isFocused = true }
    }

    private func saveAndDismiss() {
        save(name)
        dismiss()
    }
}
