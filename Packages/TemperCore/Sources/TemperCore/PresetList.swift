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

    /// What setup shows under its title: the picked Preset's name, or nothing with nothing picked.
    public var subtitle: String? {
        picked?.name
    }

    /// The first problem with a name, or `nil` if a Preset can take it. The name is trimmed first.
    public func nameProblem(_ name: String) -> PresetNameProblem? {
        let trimmed = Self.trimmed(name)
        if trimmed.isEmpty {
            return .empty
        }
        if trimmed.count > PresetNameProblem.maximumLength {
            return .tooLong
        }
        if let existing = presets.first(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
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
