// PROBE, throwaway. HealthKit calls both sides share: the permission status, and a listing of every workout the
// probe saved, with its source, sync version, activities, events and linked heart-rate samples.

import Foundation
import HealthKit

enum ProbeHealth {
    static let markerKey = "TemperProbe"
    static let runKey = "TemperProbeRun"
    static let phaseKey = "TemperPhase"
    static let roundKey = "TemperRound"
    /// Above any iPhone attempt, as the #103 research proposed.
    static let watchSyncVersion = 1_000_000

    static let share: Set<HKSampleType> = [HKObjectType.workoutType()]
    /// Workouts are read so each side can see the other's saves. The real apps don't read them.
    static let read: Set<HKObjectType> = [HKObjectType.workoutType(), HKQuantityType(.heartRate)]

    /// One line: workout sharing status, whether a request would prompt, and this app's Health source.
    static func status(_ store: HKHealthStore) async -> String {
        let share = store.authorizationStatus(for: HKObjectType.workoutType()).label
        let request: String
        do {
            request = try await store.statusForAuthorizationRequest(toShare: Self.share, read: Self.read).label
        } catch {
            request = "error \(error.localizedDescription)"
        }
        return "workouts \(share); a request would \(request); source \(HKSource.default().bundleIdentifier)"
    }

    static func listProbeWorkouts(_ store: HKHealthStore) async -> [String] {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(HKQuery.predicateForObjects(withMetadataKey: markerKey))],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)],
            limit: 20)
        let workouts: [HKWorkout]
        do {
            workouts = try await descriptor.result(for: store)
        } catch {
            return ["probe workouts: query failed: \(error.localizedDescription)"]
        }
        var lines = ["probe workouts visible here: \(workouts.count)"]
        for workout in workouts {
            lines.append(contentsOf: await describe(workout, store: store))
        }
        return lines
    }

    static func describe(_ workout: HKWorkout, store: HKHealthStore) async -> [String] {
        let metadata = workout.metadata ?? [:]
        let source = workout.sourceRevision.source
        let syncID = (metadata[HKMetadataKeySyncIdentifier] as? String).map { String($0.prefix(8)) } ?? "none"
        let version = (metadata[HKMetadataKeySyncVersion] as? NSNumber).map { "\($0)" } ?? "none"
        let heartRate = HKQuantityType(.heartRate)
        let bpm = HKUnit.count().unitDivided(by: .minute())
        let average = workout.statistics(for: heartRate)?.averageQuantity()?.doubleValue(for: bpm)
        let energy = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?
            .doubleValue(for: .kilocalorie())
        var lines = [
            "• \(ProbeLog.time(workout.startDate))–\(ProbeLog.time(workout.endDate)), \(Int(workout.duration)) s, "
                + "\(workout.workoutActivityType.label), run \(metadata[runKey] as? String ?? "?"), "
                + "uuid \(workout.uuid.uuidString.prefix(8))",
            "  source \(source.name) [\(source.bundleIdentifier)], device \(workout.device?.name ?? "none") "
                + "\(workout.device?.model ?? ""), sync \(syncID) v\(version)",
            "  avg HR \(average.map { "\(Int($0))" } ?? "none"), active energy "
                + "\(energy.map { "\(Int($0)) kcal" } ?? "none"), statistics for "
                + workout.allStatistics.keys.map(\.short).sorted().joined(separator: ", "),
        ]
        let events = workout.workoutEvents ?? []
        lines.append(
            "  \(events.count) events: "
                + events.map { "\($0.type.label) +\(offset($0.dateInterval.start, from: workout))" }
                .joined(separator: ", "))
        lines.append("  \(workout.workoutActivities.count) activities")
        for activity in workout.workoutActivities {
            let activityMetadata = activity.metadata ?? [:]
            let activityAverage = activity.statistics(for: heartRate)?.averageQuantity()?.doubleValue(for: bpm)
            lines.append(
                "    \(activityMetadata[phaseKey] as? String ?? "?") \(activityMetadata[roundKey] ?? "-"): "
                    + "+\(offset(activity.startDate, from: workout)) to "
                    + "\(activity.endDate.map { "+" + offset($0, from: workout) } ?? "open"), "
                    + "avg HR \(activityAverage.map { "\(Int($0))" } ?? "none")")
        }
        let linked = await heartRateSamples(HKQuery.predicateForObjects(from: workout), store: store)
        let inSpan = await heartRateSamples(
            HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate), store: store)
        lines.append("  heart-rate samples linked to it: \(linked); in its span: \(inSpan)")
        return lines
    }

    /// A count and the sources, or the error.
    private static func heartRateSamples(_ predicate: NSPredicate, store: HKHealthStore) async -> String {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: HKQuantityType(.heartRate), predicate: predicate)],
            sortDescriptors: [])
        do {
            let samples = try await descriptor.result(for: store)
            let sources = Set(samples.map { $0.sourceRevision.source.bundleIdentifier }).sorted()
            return "\(samples.count) from [\(sources.joined(separator: ", "))]"
        } catch {
            return "query failed: \(error.localizedDescription)"
        }
    }

    private static func offset(_ date: Date, from workout: HKWorkout) -> String {
        String(format: "%.2f s", date.timeIntervalSince(workout.startDate))
    }
}

extension HKWorkoutActivityType {
    nonisolated var label: String {
        switch self {
        case .highIntensityIntervalTraining: "HIIT"
        case .traditionalStrengthTraining: "traditional strength"
        case .other: "other"
        default: "type \(rawValue)"
        }
    }
}

extension HKWorkoutEventType {
    nonisolated var label: String {
        switch self {
        case .pause: "pause"
        case .resume: "resume"
        case .segment: "segment"
        case .marker: "marker"
        case .lap: "lap"
        case .motionPaused: "motion paused"
        case .motionResumed: "motion resumed"
        case .pauseOrResumeRequest: "pause or resume request"
        @unknown default: "event \(rawValue)"
        }
    }
}

extension HKAuthorizationRequestStatus {
    nonisolated var label: String {
        switch self {
        case .shouldRequest: "prompt"
        case .unnecessary: "not prompt"
        case .unknown: "unknown"
        @unknown default: "unknown \(rawValue)"
        }
    }
}

extension HKObjectType {
    /// The identifier without its `HK…TypeIdentifier` prefix.
    var short: String {
        identifier.replacingOccurrences(of: "HKQuantityTypeIdentifier", with: "")
            .replacingOccurrences(of: "HKCategoryTypeIdentifier", with: "")
    }
}
