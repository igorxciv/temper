import Foundation

nonisolated extension HealthRecord {
    /// The Health workout the Watch saves by itself when the iPhone's record never arrives, built from the updates it
    /// heard, or `nil` under ``minimumActiveTime`` of active time. It's the fallback: the record in the iPhone's `end`
    /// has exact times and always wins.
    ///
    /// It spans the Start in `begin` to `lastContact`, at ``watchSyncVersion``.
    ///
    /// Each Phase heard, told apart by kind and Round, becomes an activity from its start to the next heard Phase's
    /// start. A Phase that counts down ends no later than its own end, so the stretch a dropout hid stays without an
    /// activity rather than being guessed at. A Phase that counts up has no end to stop at: an open Work runs until
    /// Done, and a Stopwatch's Work runs on past its set length.
    ///
    /// An update's `start` is where the Phase would have started with no Pause, so a Pause lasts as long as the
    /// updates after it moved that `start`. A Pause still on at the last update lasts to the end, and its Phase with
    /// it.
    ///
    /// - Parameters:
    ///   - heard: Each Phase update, in the order it arrived.
    ///   - lastContact: When the Watch last had the iPhone, or when another workout app took the Watch over.
    public init?(heard: [WatchPhase], begin: MessageToWatch.Begin, lastContact: Date) {
        let start = begin.start
        let end = max(start, lastContact)
        // The updates of each Phase, in order.
        let phases = heard.reduce(into: [[WatchPhase]]()) { phases, update in
            if let last = phases.last?.last, last.kind == update.kind, last.round == update.round {
                phases[phases.count - 1].append(update)
            } else {
                phases.append([update])
            }
        }
        var pauses: [Pause] = []
        var activities: [Activity] = []
        for (index, updates) in phases.enumerated() {
            let isLast = index == phases.count - 1
            let first = updates[0]
            let last = updates[updates.count - 1]
            let isPausedAtEnd = isLast && last.pausedAt != nil

            var phaseEnd = isLast ? end : phases[index + 1][0].start
            if let ownEnd = last.end, !last.countsUp, !isPausedAtEnd {
                phaseEnd = min(phaseEnd, ownEnd)
            }
            let activity = Activity(
                phase: first.kind, round: first.round, start: max(first.start, start), end: min(phaseEnd, end))
            if activity.start < activity.end {
                activities.append(activity)
            }

            var next = 0
            while next < updates.count {
                let paused = updates[next]
                guard let pausedAt = paused.pausedAt else {
                    next += 1
                    continue
                }
                // The Resume, or the last update of a Pause whose Resume wasn't heard.
                var latest = next
                while latest + 1 < updates.count, updates[latest].pausedAt != nil {
                    latest += 1
                }
                let isStillOn = isPausedAtEnd && latest == updates.count - 1
                let resumed =
                    isStillOn
                    ? end : pausedAt.addingTimeInterval(updates[latest].start.timeIntervalSince(paused.start))
                let pause = Pause(start: max(pausedAt, start), end: min(resumed, end))
                if pause.start < pause.end {
                    pauses.append(pause)
                }
                next = latest + 1
            }
        }
        let paused = pauses.reduce(0) { $0 + $1.end.timeIntervalSince($1.start) }
        guard end.timeIntervalSince(start) - paused >= Self.minimumActiveTime / .seconds(1) else { return nil }
        self.init(
            activityType: ActivityType(begin.workoutType), start: start, end: end, pauses: pauses,
            activities: activities, workoutID: begin.workoutID, syncVersion: Self.watchSyncVersion)
    }
}
