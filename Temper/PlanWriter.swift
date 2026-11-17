import FoundationModels
import TemperCore

/// Turns the owner's description of a Workout into a Plan with Apple's on-device language model, so the words never
/// leave the iPhone.
///
/// The model fills in a `PlanDraft` through guided generation, which keeps it to the shape and ranges below. The
/// draft's own rules then make the Plan, and the Plan still has to make a Workout before it can start.
enum PlanWriter {
    /// Why Describe can't write a Plan on this iPhone right now, in words for the screen, or `nil` if it can.
    static var unavailableReason: String? {
        switch SystemLanguageModel.default.availability {
        case .available:
            nil
        case .unavailable(.deviceNotEligible):
            "Describe needs an iPhone that supports Apple Intelligence."
        case .unavailable(.appleIntelligenceNotEnabled):
            "Turn on Apple Intelligence in Settings to use Describe."
        case .unavailable(.modelNotReady):
            "Apple Intelligence is still getting ready. Try again in a little while."
        case .unavailable:
            "Describe isn't available on this iPhone right now."
        }
    }

    /// The draft the model writes for `description`. It throws the model's errors as `PlanWriter.Failure`.
    ///
    /// Greedy sampling gives the same Plan for the same words, as a timer should.
    static func draft(for description: String) async throws(Failure) -> PlanDraft {
        let session = LanguageModelSession(instructions: instructions)
        do {
            return try await session.respond(
                to: description, generating: GeneratedPlan.self, options: GenerationOptions(samplingMode: .greedy)
            ).content.draft
        } catch let error as LanguageModelError {
            throw Failure(error)
        } catch {
            throw .other
        }
    }

    /// What went wrong writing a Plan, in words for the screen.
    enum Failure: Error {
        case notTraining
        case tooLong
        case language
        case other

        init(_ error: LanguageModelError) {
            switch error {
            case .guardrailViolation, .refusal: self = .notTraining
            case .contextSizeExceeded: self = .tooLong
            case .unsupportedLanguageOrLocale: self = .language
            default: self = .other
            }
        }

        var explanation: String {
            switch self {
            case .notTraining: "That doesn't read as a Workout. Describe the Work and Rest you want."
            case .tooLong: "That's too long to read. Describe the Workout more briefly."
            case .language: "Describe can't read that language yet."
            case .other: "Describe couldn't write a Plan. Try again."
            }
        }
    }

    /// The plan is a list of parts, each one Round's Phases and how often they run, so any Phase can go anywhere: a
    /// Cooldown between parts, Rests one after another, or several Works in a Round. The example shows a Phase that
    /// runs once as a part of its own. Asking whether a Phase is timed before its length kept a Rest length out of the
    /// Work, as checked against the on-device model when every Round was one Work and one Rest.
    private static let instructions = """
        You turn a person's description of today's training into a plan for an interval timer.

        A plan is a list of parts in the order they happen. Each part is a list of phases that runs a number of times, \
        and each run through it is one Round. The phases are Prepare, a countdown to get into position; Work; Rest; \
        and Cooldown. Any phase can go anywhere and more than once, such as a Cooldown between two parts and another \
        at the end, or two Rests one after another. A Round can hold several exercises, each its own Work. A phase \
        that happens once, such as a Prepare, a Cooldown or a longer Rest between parts, is a part of its own that \
        runs 1 time.

        Some Work is timed, such as 20 seconds of sprinting. Other Work has no time, such as a set of lifts or \
        repetitions: the person taps Done when they finish it.

        For example, "8 rounds of 20 seconds on and 10 off, a 2 minute cooldown, 8 more rounds, then 3 minutes of \
        cooldown" is four parts: 8 times Work 20 seconds and Rest 10 seconds; 1 time Cooldown 120 seconds; 8 times \
        Work 20 seconds and Rest 10 seconds; 1 time Cooldown 180 seconds.

        Use exactly the numbers the person gives. A rest length always goes in a Rest, never in a Work. Never add a \
        Prepare, a Cooldown or a Rest the person didn't ask for. Weights, percentages and repetitions aren't timer \
        settings, so leave them out.

        When the person names the exercise for a Work, such as squats or push-ups, give that Work the exercise's \
        name, such as "Squats". Leave it empty if they name none, and never make one up.
        """
}

@Generable(description: "Today's training as a timer plan")
private struct GeneratedPlan {
    @Guide(description: "Every part of the training, in the order it happens", .count(1...12))
    var parts: [GeneratedPart]

    var draft: PlanDraft {
        PlanDraft(blocks: parts.map(\.draft))
    }
}

@Generable(description: "Phases that run, in order, a number of times")
private struct GeneratedPart {
    @Guide(
        description:
            "How many times the phases run, exactly as the person says. 1 for a phase that happens once, such as a"
            + " Prepare, a Cooldown or a Rest between parts.",
        .range(1...99))
    var rounds: Int

    @Guide(description: "true only if the person wants to keep going until they stop, with no set number of Rounds")
    var untilStop: Bool

    @Guide(description: "One run's phases, in the order they happen", .count(1...8))
    var phases: [GeneratedPhase]

    var draft: PlanDraft.Block {
        PlanDraft.Block(rounds: rounds, untilStop: untilStop, phases: phases.map(\.draft))
    }
}

/// The order of the properties is the order the model writes them, so it settles whether a Phase is timed before it
/// writes any length.
@Generable(description: "One phase of the timer")
private struct GeneratedPhase {
    var kind: GeneratedKind

    @Guide(
        description:
            "true only if the person says how long it lasts. false for a set of repetitions or lifts with no time"
            + " given."
    )
    var isTimed: Bool

    @Guide(description: "How long it lasts in seconds, or 0 if isTimed is false", .range(0...1800))
    var seconds: Int

    /// Written last, so naming the exercise can't sway the lengths before it.
    @Guide(
        description:
            "For a Work, the exercise the person names, in a few words, such as Squats, without repetitions, weights"
            + " or percentages. Empty if they name none, and for any other phase."
    )
    var exercise: String

    var draft: PlanDraft.Phase {
        PlanDraft.Phase(kind.phaseKind, seconds: isTimed ? seconds : 0, exercise: exercise)
    }
}

@Generable(description: "Which phase it is")
private enum GeneratedKind {
    case prepare
    case work
    case rest
    case cooldown

    var phaseKind: Phase.Kind {
        switch self {
        case .prepare: .prepare
        case .work: .work
        case .rest: .rest
        case .cooldown: .cooldown
        }
    }
}
