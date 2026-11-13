import TemperCore
import Testing

@testable import Temper

struct CompleteHealthNoteTests {
    private let longEnough = HealthRecord.minimumActiveTime

    @Test func `Before Health's status is read, the screen says nothing about Health`() {
        #expect(CompleteHealthNote(row: nil, activeTime: longEnough) == nil)
        #expect(CompleteHealthNote(row: nil, activeTime: .seconds(10)) == nil)
    }

    @Test(arguments: [AppleHealthRow.saving, .allowHeartRate, .saveWorkouts, .notAllowed])
    func `A Workout under the minimum is never saved, whatever Health allows`(row: AppleHealthRow) {
        let note = CompleteHealthNote(row: row, activeTime: longEnough - .milliseconds(1))

        #expect(note == .tooShort)
        #expect(note?.text == "Under 1 minute, so not saved to Health.")
    }

    @Test func `A Workout of the minimum or more is saving once Health allows workouts`() {
        let note = CompleteHealthNote(row: .saving, activeTime: longEnough)

        #expect(note == .saving)
        #expect(note?.text == "Saving to Apple Health.")
        #expect(note?.systemImage == "heart.fill")
    }

    @Test func `Before heart rate has been allowed, the note says it's left out`() {
        let note = CompleteHealthNote(row: .allowHeartRate, activeTime: longEnough)

        #expect(note == .savingWithoutHeartRate)
        #expect(note?.text == "Saving to Apple Health, without heart rate.")
        #expect(note?.systemImage == "heart.fill")
    }

    @Test func `When the owner hasn't been asked, the note points to Settings`() {
        let note = CompleteHealthNote(row: .saveWorkouts, activeTime: .seconds(600))

        #expect(note == .notTurnedOn)
        #expect(note?.text == "Not saved to Health. Turn it on in Settings.")
        #expect(note?.systemImage == nil)
    }

    @Test func `When Health access is off, the note says so`() {
        let note = CompleteHealthNote(row: .notAllowed, activeTime: .seconds(600))

        #expect(note == .accessOff)
        #expect(note?.text == "Not saved: Health access is off.")
        #expect(note?.systemImage == nil)
    }
}
