import Foundation

/// The owner's description of a Workout while they dictate it on Describe: the words the recognizer has settled,
/// then the words it may still change.
///
/// Dictating replaces what was in the field, so an earlier Workout's description doesn't run on into today's. Until
/// any words are heard, the earlier description stays, so tapping the microphone and saying nothing loses nothing.
public nonisolated struct DictatedDescription: Equatable, Sendable {
    private let earlier: String
    private var settled = ""
    private var tentative = ""

    public init(replacing earlier: String) {
        self.earlier = earlier
    }

    /// Takes the recognizer's latest words. Settled words are kept. Tentative words stand in for whatever the
    /// recognizer will settle next, so they replace the last tentative words, and settling clears them.
    public mutating func hear(_ words: String, isSettled: Bool) {
        if isSettled {
            settled = Self.joined(settled, words)
            tentative = ""
        } else {
            tentative = words
        }
    }

    /// Whether the recognizer has heard any words yet.
    public var hasHeardWords: Bool {
        !Self.joined(settled, tentative).isEmpty
    }

    /// What the description field shows.
    public var text: String {
        hasHeardWords ? Self.joined(settled, tentative) : earlier
    }

    private static func joined(_ first: String, _ second: String) -> String {
        [first, second]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
