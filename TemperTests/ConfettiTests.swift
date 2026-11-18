import Foundation
import Testing

@testable import Temper

struct ConfettiTests {
    @Test func `A bigger tip throws more confetti`() {
        let counts = [TipCelebration.small, .medium, .large].map { celebration in
            Confetti(bursts: celebration.bursts, seed: 1).pieces.count
        }

        #expect(counts == counts.sorted())
        #expect(Set(counts).count == 3)
    }

    @Test(arguments: [("tip.small", TipCelebration.small), ("tip.medium", .medium), ("tip.large", .large)])
    func `Each tip gets its own celebration`(productID: String, celebration: TipCelebration) {
        #expect(TipCelebration(productID: productID) == celebration)
    }

    @Test func `A tip Temper doesn't know is thanked as a small one`() {
        #expect(TipCelebration(productID: "tip.someday") == .small)
    }

    /// The view stops redrawing at `duration`, so nothing may still show then.
    @Test func `Every piece has gone by the end`() {
        let confetti = Confetti(bursts: TipCelebration.large.bursts, seed: 7)

        #expect(confetti.pieces.allSatisfy { Confetti.pose(of: $0, at: confetti.duration) == nil })
        #expect(confetti.pieces.contains { Confetti.pose(of: $0, at: confetti.duration - 0.1) != nil })
    }

    @Test func `No piece shows before its burst is thrown`() {
        let confetti = Confetti(bursts: TipCelebration.large.bursts, seed: 7)
        let late = confetti.pieces.filter { $0.birth >= 0.9 }

        #expect(!late.isEmpty)
        #expect(late.allSatisfy { Confetti.pose(of: $0, at: 0.89) == nil })
    }

    /// Thrown out fast, then falling: a piece ends lower than it was at the top of its flight.
    @Test func `Pieces fall once the air has slowed them`() throws {
        let confetti = Confetti(bursts: [Confetti.Burst(origin: .ring, delay: 0, count: 50)], seed: 3)

        for piece in confetti.pieces {
            let early = try #require(Confetti.pose(of: piece, at: 0.5))
            let late = try #require(Confetti.pose(of: piece, at: 2))
            #expect(late.offset.dy > early.offset.dy)
        }
    }

    @Test func `The same seed throws the same confetti`() {
        let bursts = TipCelebration.medium.bursts

        #expect(Confetti(bursts: bursts, seed: 42) == Confetti(bursts: bursts, seed: 42))
        #expect(Confetti(bursts: bursts, seed: 42) != Confetti(bursts: bursts, seed: 43))
    }
}
