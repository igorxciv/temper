import Foundation
import Observation
import TemperCore

/// A tab in the tab bar: one per Workout Type that has its screens, then Describe, then Settings.
enum RootTab: Hashable {
    case workoutType(WorkoutType)
    /// Where the owner describes a Workout in words and gets a Plan.
    case describe
    case settings

    /// The Workout Types with a tab, in tab order.
    static let workoutTypes: [WorkoutType] = [.intervals, .stopwatch, .openRounds]
}

/// Each Workout Type's last-used values and Presets, the last-used Workout Type, and the Dip setting. Each change
/// saves at once, and nothing about a running Workout is ever stored here.
@Observable
final class RememberedValues {
    /// The Intervals values, under the keys Temper used before it had Workout Types, so an upgrade keeps them.
    private var intervals: WorkoutSettings {
        didSet { save(intervals, oldValue, of: .intervals) }
    }

    private var stopwatch: WorkoutSettings {
        didSet { save(stopwatch, oldValue, of: .stopwatch) }
    }

    private var openRounds: WorkoutSettings {
        didSet { save(openRounds, oldValue, of: .openRounds) }
    }

    /// Each type's Presets, which save whole whenever that type's list changes. They sit in `UserDefaults` beside
    /// the values rather than in SwiftData or a file, since the lists are small and the widget extension never
    /// reads them.
    private var presetLists: [WorkoutType: PresetList]

    /// The Workout Type Temper opens on, which is the last one whose tab was selected.
    private(set) var lastUsed: WorkoutType {
        didSet { defaults.set(lastUsed.rawValue, forKey: Self.workoutTypeKey) }
    }

    /// The tab showing when it isn't a Workout Type's: Describe or Settings. Never saved, so a launch always opens
    /// on a Workout Type.
    private var otherTab: RootTab?

    /// What the owner last wrote on Describe, kept so it can be changed and sent again.
    var workoutDescription: String {
        didSet { defaults.set(workoutDescription, forKey: Self.descriptionKey) }
    }

    /// The Plan last made on Describe, kept so a Workout from it can run again after it ends. It's stored in the
    /// Plan's own format, and one a later build wrote, which this build can't read, is forgotten.
    var describedPlan: Plan? {
        didSet {
            defaults.set(describedPlan.flatMap { try? JSONEncoder().encode($0) }, forKey: Self.describedPlanKey)
        }
    }

    /// The words `describedPlan` was made from. The same words always make the same Plan, so Describe offers a new
    /// Plan only once the description differs from these.
    var describedPlanWords: String? {
        didSet { defaults.set(describedPlanWords, forKey: Self.describedPlanWordsKey) }
    }

    var isDipOn: Bool {
        didSet {
            defaults.set(isDipOn, forKey: Self.dipKey)
        }
    }

    @ObservationIgnored private let defaults: UserDefaults

    private static let workoutTypeKey = "workoutType"
    private static let dipKey = "dip"
    private static let descriptionKey = "describe.description"
    private static let describedPlanKey = "describe.plan"
    private static let describedPlanWordsKey = "describe.planWords"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        intervals = Self.restore(.intervals, from: defaults)
        stopwatch = Self.restore(.stopwatch, from: defaults)
        openRounds = Self.restore(.openRounds, from: defaults)
        presetLists = Dictionary(
            uniqueKeysWithValues: WorkoutType.allCases.map { ($0, Self.restorePresets(of: $0, from: defaults)) })
        // A type with no tab can't be selected, so it opens on Intervals instead.
        let stored = defaults.string(forKey: Self.workoutTypeKey).flatMap(WorkoutType.init)
        lastUsed = stored.flatMap { RootTab.workoutTypes.contains($0) ? $0 : nil } ?? .intervals
        isDipOn = defaults.object(forKey: Self.dipKey) as? Bool ?? true
        workoutDescription = defaults.string(forKey: Self.descriptionKey) ?? ""
        describedPlan = defaults.data(forKey: Self.describedPlanKey).flatMap {
            try? JSONDecoder().decode(Plan.self, from: $0)
        }
        describedPlanWords = defaults.string(forKey: Self.describedPlanWordsKey)
    }

    /// A Workout Type's values. Only the values on its setup save.
    subscript(workoutType: WorkoutType) -> WorkoutSettings {
        get {
            switch workoutType {
            case .intervals: intervals
            case .stopwatch: stopwatch
            case .openRounds: openRounds
            }
        }
        set {
            switch workoutType {
            case .intervals: intervals = newValue
            case .stopwatch: stopwatch = newValue
            case .openRounds: openRounds = newValue
            }
        }
    }

    /// A Workout Type's Presets, in menu order, and the one its setup picked.
    func presets(of workoutType: WorkoutType) -> PresetList {
        presetLists[workoutType] ?? PresetList(workoutType: workoutType)
    }

    /// Saves the values on the type's setup as a new Preset at the end of its list, and picks it.
    func saveAsNewPreset(named name: String, of workoutType: WorkoutType) throws(PresetNameProblem) {
        let settings = self[workoutType]
        try changePresets(of: workoutType) { list throws(PresetNameProblem) in
            try list.saveAsNew(named: name, settings: settings)
        }
    }

    /// Picks a Preset and puts its values on the type's setup, where they save as any other change does.
    func pickPreset(_ id: Preset.ID, of workoutType: WorkoutType) {
        if let settings = changePresets(of: workoutType, { $0.pick(id) }) {
            self[workoutType] = settings
        }
    }

    /// Saves the values on the type's setup over its picked Preset. With nothing picked it does nothing.
    func updatePickedPreset(of workoutType: WorkoutType) {
        let settings = self[workoutType]
        changePresets(of: workoutType) { $0.updatePicked(with: settings) }
    }

    /// Renames one of the type's Presets. A picked Preset stays picked.
    func renamePreset(_ id: Preset.ID, to name: String, of workoutType: WorkoutType) throws(PresetNameProblem) {
        try changePresets(of: workoutType) { list throws(PresetNameProblem) in
            try list.rename(id, to: name)
        }
    }

    /// Deletes one of the type's Presets. Setup's values stay as they are, even when it was the picked one.
    func deletePreset(_ id: Preset.ID, of workoutType: WorkoutType) {
        changePresets(of: workoutType) { $0.delete(id) }
    }

    /// Reorders the type's Presets by the offsets `onMove` reports. The picked Preset stays picked.
    func movePresets(fromOffsets offsets: IndexSet, toOffset destination: Int, of workoutType: WorkoutType) {
        changePresets(of: workoutType) { $0.move(fromOffsets: offsets, toOffset: destination) }
    }

    /// The tab showing. Selecting a Workout Type's tab makes it the last-used Workout Type, and selecting
    /// Describe or Settings doesn't, so leaving a Workout always comes back to the tab it started from.
    var selectedTab: RootTab {
        get { otherTab ?? .workoutType(lastUsed) }
        set {
            switch newValue {
            case .workoutType(let workoutType):
                otherTab = nil
                if lastUsed != workoutType {
                    lastUsed = workoutType
                }
            case .describe, .settings:
                otherTab = newValue
            }
        }
    }

    /// Changes one type's list, which then saves whole.
    private func changePresets<Result, Failure>(
        of workoutType: WorkoutType,
        _ change: (inout PresetList) throws(Failure) -> Result
    ) throws(Failure) -> Result {
        var list = presets(of: workoutType)
        let result = try change(&list)
        presetLists[workoutType] = list
        save(list)
        return result
    }

    private func save(_ settings: WorkoutSettings, _ oldSettings: WorkoutSettings, of workoutType: WorkoutType) {
        for value in workoutType.values where settings[value] != oldSettings[value] {
            defaults.set(settings[value], forKey: value.defaultsKey(for: workoutType))
        }
    }

    /// Writes the whole list and its pick. Lists are short, so there is no partial write.
    private func save(_ list: PresetList) {
        let workoutType = list.workoutType
        let stored = list.presets.map { preset in
            StoredPreset(
                id: preset.id.uuidString,
                name: preset.name,
                values: Dictionary(
                    uniqueKeysWithValues: workoutType.values.map { ($0.storedName, preset.settings[$0]) })
            )
        }
        if let data = try? JSONEncoder().encode(stored) {
            defaults.set(data, forKey: Self.presetsKey(for: workoutType))
        }
        defaults.set(list.pickedID?.uuidString, forKey: Self.pickedPresetKey(for: workoutType))
    }

    private static func restore(_ workoutType: WorkoutType, from defaults: UserDefaults) -> WorkoutSettings {
        workoutType.restoredSettings { defaults.object(forKey: $0.defaultsKey(for: workoutType)) as? Int }
    }

    /// Each Preset's values restore as the remembered values do. An entry that can't be read is dropped, and
    /// unreadable data is an empty list.
    private static func restorePresets(of workoutType: WorkoutType, from defaults: UserDefaults) -> PresetList {
        let entries =
            defaults.data(forKey: presetsKey(for: workoutType))
            .flatMap { try? JSONDecoder().decode([LenientStoredPreset].self, from: $0) } ?? []
        let presets = entries.compactMap(\.preset).compactMap { stored -> Preset? in
            guard let id = UUID(uuidString: stored.id) else { return nil }
            let settings = workoutType.restoredSettings { stored.values[$0.storedName] }
            return Preset(id: id, name: stored.name, settings: settings)
        }
        let pickedID = defaults.string(forKey: pickedPresetKey(for: workoutType)).flatMap(UUID.init(uuidString:))
        return PresetList(workoutType: workoutType, restoring: presets, pickedID: pickedID)
    }

    /// The suffix is the raw value, so renaming a case forgets that type's Presets.
    private static func presetsKey(for workoutType: WorkoutType) -> String {
        "presets.\(workoutType.rawValue)"
    }

    private static func pickedPresetKey(for workoutType: WorkoutType) -> String {
        "pickedPreset.\(workoutType.rawValue)"
    }
}

extension WorkoutType {
    /// The type's first-launch values, with each stored value its setup shows taken in clamped.
    fileprivate func restoredSettings(_ stored: (WorkoutValue) -> Int?) -> WorkoutSettings {
        var settings = firstLaunch
        for value in values {
            if let amount = stored(value) {
                settings[value] = value.clamped(amount)
            }
        }
        return settings
    }
}

extension WorkoutValue {
    /// Intervals keeps the keys from before Workout Types, and every other type prefixes its own name.
    fileprivate func defaultsKey(for workoutType: WorkoutType) -> String {
        workoutType == .intervals ? storedName : "\(workoutType.rawValue).\(storedName)"
    }

    /// The value's name in its `UserDefaults` key and in a stored Preset.
    fileprivate var storedName: String {
        switch self {
        case .prepare: "prepare"
        case .rounds: "rounds"
        case .work: "work"
        case .rest: "rest"
        case .cooldown: "cooldown"
        }
    }
}

/// A Preset as `UserDefaults` keeps it, in JSON: its values are whole seconds or a Round count, by value name.
private nonisolated struct StoredPreset: Codable {
    var id: String
    var name: String
    var values: [String: Int]
}

/// One stored entry, or `nil` if it can't be read, so one bad entry doesn't lose the rest of the list.
private nonisolated struct LenientStoredPreset: Decodable {
    let preset: StoredPreset?

    init(from decoder: any Decoder) throws {
        preset = try? StoredPreset(from: decoder)
    }
}
