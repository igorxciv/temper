import Foundation
import Testing

@testable import TemperCore

nonisolated struct PlanCodingTests {
    private let chest = Plan(
        activity: .traditionalStrengthTraining,
        blocks: [
            .phase(PlannedPhase(kind: .prepare, duration: .seconds(10))),
            .rounds(
                .times(10),
                [PlannedPhase(kind: .work, length: .open), PlannedPhase(kind: .rest, duration: .seconds(60))]
            ),
        ],
        warnsBeforeRestEnds: true
    )

    private func json(_ plan: Plan) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return String(decoding: try encoder.encode(plan), as: UTF8.self)
    }

    private func decode(_ json: String) throws -> Plan {
        try JSONDecoder().decode(Plan.self, from: Data(json.utf8))
    }

    /// What's stored can't change by accident: a stored Plan must read the same in every later build.
    @Test func `A Plan is stored in its documented shape`() throws {
        let expected =
            #"{"activity":"traditionalStrengthTraining","blocks":["#
            + #"{"phase":{"kind":"prepare","length":"set","seconds":10}},"#
            + #"{"rounds":{"phases":[{"kind":"work","length":"open"},{"kind":"rest","length":"set","seconds":60}],"#
            + #""times":10}}],"version":1,"warnsBeforeRestEnds":true}"#

        #expect(try json(chest) == expected)
    }

    @Test func `Rounds until Stop and a length a Phase runs past are stored by name`() throws {
        let plan = Plan(
            activity: .other,
            blocks: [
                .phase(PlannedPhase(kind: .work, length: .runsPast(.seconds(600)))),
                .rounds(.untilStop, [PlannedPhase(kind: .work, length: .open)]),
            ]
        )

        let stored = try json(plan)

        #expect(stored.contains(#"{"kind":"work","length":"runsPast","seconds":600}"#))
        #expect(stored.contains(#"{"rounds":{"phases":[{"kind":"work","length":"open"}],"untilStop":true}}"#))
    }

    @Test(arguments: WorkoutType.allCases)
    func `Each Workout Type's Plan reads back as it was stored`(type: WorkoutType) throws {
        let plan = type.plan(from: type.firstLaunch)

        #expect(try JSONDecoder().decode(Plan.self, from: JSONEncoder().encode(plan)) == plan)
    }

    @Test func `A length with part of a second reads back exactly`() throws {
        let plan = Plan(activity: .other, blocks: [.phase(PlannedPhase(kind: .work, duration: .milliseconds(2500)))])

        #expect(try decode(json(plan)) == plan)
    }

    @Test func `A Plan stored without the Rest warning reads as having none`() throws {
        let plan = try decode(
            #"{"version":1,"activity":"other","blocks":[{"phase":{"kind":"work","length":"open"}}]}"#)

        #expect(!plan.warnsBeforeRestEnds)
    }

    @Test func `A later format fails to read, so it never runs the wrong Workout`() {
        #expect(throws: DecodingError.self) {
            try decode(#"{"version":2,"activity":"other","blocks":[]}"#)
        }
    }

    @Test(arguments: [
        #"{"rounds":{"times":3,"untilStop":true,"phases":[]}}"#,
        #"{"rounds":{"phases":[]}}"#,
        #"{"phase":{"kind":"work","length":"open"},"rounds":{"times":3,"phases":[]}}"#,
        #"{}"#,
        #"{"phase":{"kind":"warmUp","length":"open"}}"#,
        #"{"phase":{"kind":"work","length":"set"}}"#,
    ])
    func `A Block that isn't exactly one Phase or one set of Rounds fails to read`(block: String) {
        #expect(throws: DecodingError.self) {
            try decode(#"{"version":1,"activity":"other","blocks":[\#(block)]}"#)
        }
    }
}
