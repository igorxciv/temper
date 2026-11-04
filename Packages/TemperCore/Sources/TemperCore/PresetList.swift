import Foundation

/// One Workout Type's Presets, in the order its title menu lists them, and the one setup last picked.
public nonisolated struct PresetList: Equatable, Sendable {
    public let workoutType: WorkoutType
    public private(set) var presets: [Preset]
    public private(set) var pickedID: Preset.ID?

    public init(workoutType: WorkoutType) {
        self.workoutType = workoutType
        presets = []
        pickedID = nil
    }

    /// The list as it was stored. A Preset whose name fails the name check is dropped and the rest survive,
    /// and a pick that matches no Preset left means nothing is picked.
    public init(workoutType: WorkoutType, restoring stored: [Preset], pickedID: Preset.ID?) {
        self.init(workoutType: workoutType)
        for preset in stored where nameProblem(preset.name) == nil {
            presets.append(
                Preset(
                    id: preset.id,
                    name: Self.trimmed(preset.name),
                    settings: workoutType.ownValues(of: preset.settings)
                )
            )
        }
        self.pickedID = presets.contains { $0.id == pickedID } ? pickedID : nil
    }

    /// The Preset setup last picked, if any.
    public var picked: Preset? {
        presets.first { $0.id == pickedID }
    }

    /// Whether setup's settings differ from the picked Preset's in any value the type's setup shows. With
    /// nothing picked, nothing is modified.
    public func isModified(_ settings: WorkoutSettings) -> Bool {
        guard let picked else { return false }
        return workoutType.values.contains { settings[$0] != picked.settings[$0] }
    }

    /// What setup shows under its title: nothing with nothing picked, the picked Preset's name, or the name
    /// and "Modified" once setup's settings differ from it.
    public func subtitle(for settings: WorkoutSettings) -> String? {
        guard let picked else { return nil }
        return isModified(settings) ? "\(picked.name) · Modified" : picked.name
    }

    /// The first problem with a name, or `nil` if a Preset can take it. The name is trimmed first. The Preset
    /// being renamed is left out, so it can change only the case of its own name.
    public func nameProblem(_ name: String, excluding excluded: Preset.ID? = nil) -> PresetNameProblem? {
        let trimmed = Self.trimmed(name)
        if trimmed.isEmpty {
            return .empty
        }
        if trimmed.count > PresetNameProblem.maximumLength {
            return .tooLong
        }
        if let existing = presets.first(where: {
            $0.id != excluded && $0.name.caseInsensitiveCompare(trimmed) == .orderedSame
        }) {
            return .taken(existingName: existing.name, workoutType: workoutType)
        }
        return nil
    }

    /// Adds a Preset holding these settings at the end under the trimmed name, and picks it. A name with a
    /// problem throws it and changes nothing.
    public mutating func saveAsNew(named name: String, settings: WorkoutSettings) throws(PresetNameProblem) {
        if let problem = nameProblem(name) {
            throw problem
        }
        let preset = Preset(name: Self.trimmed(name), settings: workoutType.ownValues(of: settings))
        presets.append(preset)
        pickedID = preset.id
    }

    /// Picks a Preset and hands back its settings for setup. Picking the picked Preset again hands them back
    /// too, so it discards changes made on setup. An unknown Preset changes nothing.
    public mutating func pick(_ id: Preset.ID) -> WorkoutSettings? {
        guard let preset = presets.first(where: { $0.id == id }) else { return nil }
        pickedID = id
        return preset.settings
    }

    /// Replaces the picked Preset's settings with setup's, so it's no longer modified. With nothing picked it
    /// does nothing.
    public mutating func updatePicked(with settings: WorkoutSettings) {
        guard let index = presets.firstIndex(where: { $0.id == pickedID }) else { return }
        presets[index].settings = workoutType.ownValues(of: settings)
    }

    /// Gives a Preset the trimmed name and keeps the pick. A name with a problem throws it and changes nothing,
    /// and so does an unknown Preset.
    public mutating func rename(_ id: Preset.ID, to name: String) throws(PresetNameProblem) {
        guard let index = presets.firstIndex(where: { $0.id == id }) else { return }
        if let problem = nameProblem(name, excluding: id) {
            throw problem
        }
        presets[index].name = Self.trimmed(name)
    }

    /// Removes a Preset. Deleting the picked one leaves nothing picked, and setup's values stay as they are.
    public mutating func delete(_ id: Preset.ID) {
        presets.removeAll { $0.id == id }
        if pickedID == id {
            pickedID = nil
        }
    }

    /// Reorders Presets the way SwiftUI's `onMove` reports a drag: the Presets at these offsets go before the
    /// one at `destination`, counted in the order before the move. The pick is kept.
    public mutating func move(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        // SwiftUI's own `move(fromOffsets:toOffset:)` isn't in Foundation, and TemperCore doesn't import SwiftUI.
        let moved = offsets.map { presets[$0] }
        let before = presets.indices.filter { $0 < destination && !offsets.contains($0) }.map { presets[$0] }
        let after = presets.indices.filter { $0 >= destination && !offsets.contains($0) }.map { presets[$0] }
        presets = before + moved + after
    }

    private static func trimmed(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension WorkoutType {
    /// The settings with every value its setup doesn't show back at first launch, so a Preset never carries
    /// stray values and equals what this type would build.
    fileprivate nonisolated func ownValues(of settings: WorkoutSettings) -> WorkoutSettings {
        var own = firstLaunch
        for value in values {
            own[value] = settings[value]
        }
        return own
    }
}
