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

    /// Checked against the on-device model with descriptions of sets with no time, timed intervals, Rounds until Stop
    /// and a Cooldown. Naming the Work and Rest lengths, and asking whether Work is timed first, kept a Rest length
    /// out of the Work.
    private static let instructions = """
        You turn a person's description of today's training into a plan for an interval timer.

        A plan is an optional Prepare countdown, then one or more blocks of Rounds, then an optional Cooldown. Each \
        Round is one Work followed by one Rest. Some Work is timed, such as 20 seconds of sprinting. Other Work has no \
        time, such as a set of lifts or repetitions: the person taps Done when they finish it.

        Use exactly the numbers the person gives. A rest length always goes in restSeconds, never in workSeconds. \
        Never add a Prepare, a Cooldown or a Rest the person didn't ask for. Weights, percentages and repetitions \
        aren't timer settings, so leave them out.
        """
}

@Generable(description: "Today's training as a timer plan")
private struct GeneratedPlan {
    @Guide(
        description: "Seconds of countdown before the first Work, or 0 if the person doesn't ask for one",
        .range(0...1800))
    var prepareSeconds: Int

    @Guide(description: "The blocks of Rounds, in order. Usually one.", .count(1...5))
    var blocks: [GeneratedBlock]

    @Guide(
        description: "Seconds of cooldown after the last Work, or 0 if the person doesn't ask for one",
        .range(0...1800))
    var cooldownSeconds: Int

    var draft: PlanDraft {
        PlanDraft(prepareSeconds: prepareSeconds, blocks: blocks.map(\.draft), cooldownSeconds: cooldownSeconds)
    }
}

/// The order of the properties is the order the model writes them, so it settles whether Work is timed before it
/// writes any length.
@Generable(description: "Rounds of one Work followed by one Rest")
private struct GeneratedBlock {
    @Guide(description: "How many Rounds or sets, exactly as the person says", .range(1...99))
    var rounds: Int

    @Guide(description: "true only if the person wants to keep going until they stop, with no set number of Rounds")
    var untilStop: Bool

    @Guide(
        description:
            "true only if the person says how long each Work lasts. false for sets of repetitions or lifts with no"
            + " time given."
    )
    var workIsTimed: Bool

    @Guide(description: "How long each Work lasts in seconds, or 0 if workIsTimed is false", .range(0...1800))
    var workSeconds: Int

    @Guide(description: "How long each Rest between Works lasts in seconds, or 0 for no Rest", .range(0...1800))
    var restSeconds: Int

    var draft: PlanDraft.Block {
        PlanDraft.Block(
            rounds: rounds, untilStop: untilStop, workSeconds: workIsTimed ? workSeconds : 0, restSeconds: restSeconds)
    }
}
