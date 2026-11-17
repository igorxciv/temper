import SwiftUI

/// Settings' tip jar, the only place Temper mentions tips: nothing asks at launch, at Start or at the end of a Workout.
/// A tip unlocks nothing, and is thanked in place. The tips load again whenever Temper comes to the front, so ones
/// that couldn't load offline show once it's back online.
struct TipJarSection: View {
    let tipJar: TipJar
    let colors: InkColors

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Section {
            Group {
                switch tipJar.shelf {
                case .loading:
                    ProgressView()
                        .frame(maxWidth: .infinity)
                case .ready(let tips):
                    ForEach(tips) { tip in
                        Button {
                            Task { await tipJar.tip(tip.id) }
                        } label: {
                            LabeledContent {
                                Text(tip.price).foregroundStyle(colors.accent)
                            } label: {
                                Text(tip.name).foregroundStyle(colors.text)
                            }
                        }
                        .disabled(tipJar.purchasing != nil)
                    }
                case .unavailable:
                    Text("Tips can't load right now.")
                        .foregroundStyle(colors.secondary)
                }
                if let outcome = tipJar.outcome {
                    Text(outcome.message)
                        .foregroundStyle(colors.text)
                }
            }
            .listRowBackground(colors.raised)
        } header: {
            Text("Support Temper").foregroundStyle(colors.secondary)
        } footer: {
            Text("Temper is free and has no ads. Tips keep it on the App Store.")
                .foregroundStyle(colors.secondary)
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
}

extension TipJar.Outcome {
    fileprivate var message: String {
        switch self {
        case .thanks: "Thank you for supporting Temper."
        case .failed: "That tip didn't go through."
        }
    }
}
