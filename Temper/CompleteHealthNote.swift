import SwiftUI
import TemperCore

/// The one line a complete screen gives Health: whether this Workout goes to Apple Health, and if not, why.
///
/// It only says what `HealthSaves` will do with the Workout. It never asks for access, since a prompt over a finished
/// Workout would be the wrong moment; Settings is where that's asked.
enum CompleteHealthNote: Equatable {
    /// The Workout ran for under ``HealthRecord/minimumActiveTime``, so it makes no Health workout.
    case tooShort
    case saving
    /// The owner hasn't been asked yet.
    case notTurnedOn
    /// The owner said no, or the device has no Health.
    case accessOff

    /// The note for a Workout of `activeTime`, or `nil` before Health's status has been read, when there's nothing
    /// honest to say.
    init?(row: AppleHealthRow?, activeTime: Duration) {
        guard let row else { return nil }
        guard activeTime >= HealthRecord.minimumActiveTime else {
            self = .tooShort
            return
        }
        switch row {
        case .saving, .allowHeartRate: self = .saving
        case .saveWorkouts: self = .notTurnedOn
        case .notAllowed: self = .accessOff
        }
    }

    var text: String {
        switch self {
        case .tooShort: "Under 1 minute, so not saved to Health."
        case .saving: "Saving to Apple Health."
        case .notTurnedOn: "Not saved to Health. Turn it on in Settings."
        case .accessOff: "Not saved: Health access is off."
        }
    }

    /// The symbol before the text, only when the Workout is going to Health.
    var systemImage: String? {
        self == .saving ? "heart.fill" : nil
    }
}

/// A complete screen's Health line. It reads Health's status as it appears, since Settings may never have been opened
/// to read it.
struct CompleteHealthLine: View {
    let health: HealthSaves
    let activeTime: Duration

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let ink = BoardInk(contrast: contrast)

        // A stack rather than a group, so the task runs even while there's no line to show.
        VStack(alignment: .leading, spacing: 0) {
            if let note = CompleteHealthNote(row: health.row, activeTime: activeTime) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    if let systemImage = note.systemImage {
                        Image(systemName: systemImage)
                            .foregroundStyle(ink.marker)
                            .accessibilityHidden(true)
                    }
                    Text(note.text)
                        .foregroundStyle(ink.secondary)
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
            }
        }
        .task {
            await health.refreshStatus()
        }
    }
}
