import SwiftUI

/// Settings' tip jar, the only place Temper mentions tips: nothing asks at launch, at Start or at the end of a Workout.
/// A tip unlocks nothing, and is thanked in place, in the footer, since only the tips are rows to tap. The tips load
/// again whenever Temper comes to the front, so ones that couldn't load offline show once it's back online.
struct TipJarSection: View {
    let tipJar: TipJar
    let colors: InkColors

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Section {
            if case .ready(let tips) = tipJar.shelf {
                ForEach(tips) { tip in
                    Button {
                        Task { await tipJar.tip(tip.id) }
                    } label: {
                        LabeledContent {
                            Text(tip.price).foregroundStyle(colors.text)
                        } label: {
                            Text(tip.name).foregroundStyle(colors.accent)
                        }
                    }
                    .disabled(tipJar.purchasing != nil)
                    .listRowBackground(colors.raised)
                }
            }
        } header: {
            Text("Support Temper").foregroundStyle(colors.secondary)
        } footer: {
            VStack(alignment: .leading, spacing: 8) {
                Text("Temper is free and has no ads. Tips keep it on the App Store.")
                    .foregroundStyle(colors.secondary)
                if let status {
                    Text(status).foregroundStyle(colors.text)
                }
            }
        }
        .task(id: scenePhase) {
            if scenePhase == .active, tipJar.purchasing == nil {
                await tipJar.load()
            }
        }
        .onChange(of: tipJar.outcome) { _, outcome in
            if let outcome {
                AccessibilityNotification.Announcement(outcome.message).post()
            }
        }
    }

    /// The line under the copy: how the last tip went, or why there are no tips to tap.
    private var status: String? {
        if let outcome = tipJar.outcome {
            outcome.message
        } else if tipJar.shelf == .unavailable {
            "Tips can't load right now."
        } else {
            nil
        }
    }
}

extension TipJar.Outcome {
    fileprivate var message: String {
        switch self {
        case .thanks: "Thank you for supporting Temper."
        case .failed: "That tip didn't go through."
        }
    }
}
