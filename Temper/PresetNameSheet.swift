import SwiftUI
import TemperCore

/// Names a Preset. Save hands the name back once the name check passes, and Cancel or swiping the sheet away
/// discards it, as the value sheet does.
struct PresetNameSheet: View {
    let title: String
    let check: (String) -> PresetNameProblem?
    let save: (String) -> Void

    @State private var name: String
    @FocusState private var isFocused: Bool

    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dismiss) private var dismiss

    init(
        title: String,
        name: String = "",
        check: @escaping (String) -> PresetNameProblem?,
        save: @escaping (String) -> Void
    ) {
        self.title = title
        self.check = check
        self.save = save
        _name = State(initialValue: name)
    }

    var body: some View {
        let colors = InkColors(contrast: contrast)
        let problem = check(name)

        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .focused($isFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            if problem == nil {
                                confirm()
                            }
                        }
                        .listRowBackground(colors.background)
                } footer: {
                    if let footer = problem?.footer {
                        Text(footer).foregroundStyle(colors.secondary)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", role: .confirm, action: confirm)
                        .disabled(problem != nil)
                }
            }
        }
        .onAppear {
            isFocused = true
        }
        // VoiceOver hears why Save went disabled without leaving the field.
        .onChange(of: problem?.footer) { _, footer in
            if let footer {
                AccessibilityNotification.Announcement(footer).post()
            }
        }
        .presentationDetents([.medium])
        .presentationBackground(colors.raised)
    }

    private func confirm() {
        save(name)
        dismiss()
    }
}
