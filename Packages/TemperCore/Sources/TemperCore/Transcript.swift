/// The words heard so far while the owner dictates a description on Describe.
///
/// Speech recognition reports words in pieces. A settled piece won't change and the next piece follows it. A piece
/// that isn't settled yet shows at once but may be revised, so each revision replaces the last until the piece
/// settles.
public nonisolated struct Transcript: Equatable, Sendable {
    private var settled = ""
    private var revising = ""

    public init() {}

    /// The words so far, with no space at either end.
    public var text: String {
        Self.joined(settled, revising).trimmingWhitespace
    }

    /// Takes in one piece the recognizer reported. `isFinal` says it won't change again.
    public mutating func hear(_ piece: String, isFinal: Bool) {
        if isFinal {
            settled = Self.joined(settled, piece)
            revising = ""
        } else {
            revising = piece
        }
    }

    /// Puts a space between two pieces unless one is already there, so "sets." and "1 minute" don't run together.
    private static func joined(_ first: String, _ second: String) -> String {
        guard let last = first.last, let next = second.first, !last.isWhitespace, !next.isWhitespace else {
            return first + second
        }
        return first + " " + second
    }
}

extension String {
    fileprivate nonisolated var trimmingWhitespace: String {
        String(drop(while: \.isWhitespace).reversed().drop(while: \.isWhitespace).reversed())
    }
}
