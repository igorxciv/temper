// PROTOTYPE, throw away. Thread-safe JSONL log plus the timing state the screen reads.
import AVFAudio
import Foundation

final class RunLog: @unchecked Sendable {
    struct Snapshot {
        var phase = "-"
        var remaining: Duration = .zero
        var paused = false
        var finished = false
        var worstPhaseLateMs = 0.0
        var worstOnsetErrorMs = 0.0
        var cuesSkipped = 0
        var lastEvent = "-"
        var phaseChanges = 0
    }

    let url: URL
    private let lock = NSLock()
    private let handle: FileHandle?
    private let clock = ContinuousClock()
    private let startInstant: ContinuousClock.Instant
    private var calibWall = 0.0
    private var calibMach = 0.0
    private var targetWall: Double?
    private var closed = false
    private var state = Snapshot()
    private var endOfPhase: ContinuousClock.Instant?

    init(name: String) {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        url = docs.appending(path: "\(name).jsonl")
        FileManager.default.createFile(atPath: url.path, contents: nil)
        handle = try? FileHandle(forWritingTo: url)
        startInstant = clock.now
    }

    var wall: Double { Self.seconds(startInstant.duration(to: clock.now)) }

    static func seconds(_ d: Duration) -> Double {
        Double(d.components.seconds) + Double(d.components.attoseconds) * 1e-18
    }

    func write(_ kind: String, _ fields: [String: any Sendable] = [:]) {
        var object: [String: Any] = ["e": kind, "wall": wall]
        for (key, value) in fields { object[key] = value }
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        else { return }
        lock.lock()
        defer { lock.unlock() }
        guard !closed else { return }
        handle?.write(data + Data("\n".utf8))
        state.lastEvent = kind
    }

    func calibrate() {
        let w = wall
        let m = AVAudioTime.seconds(forHostTime: mach_absolute_time())
        lock.withLock {
            calibWall = w
            calibMach = m
        }
    }

    func wall(forHostSeconds host: Double) -> Double {
        lock.withLock { calibWall + (host - calibMach) }
    }

    func setCueTarget(_ wall: Double?) { lock.withLock { targetWall = wall } }

    func recordOnset(wall onset: Double) {
        let target = lock.withLock { targetWall }
        var fields: [String: any Sendable] = ["onset_wall": onset]
        if let target {
            let errorMs = (onset - target) * 1000
            fields["error_ms"] = errorMs
            lock.withLock { state.worstOnsetErrorMs = max(state.worstOnsetErrorMs, abs(errorMs)) }
        }
        write("onset", fields)
    }

    func recordPhaseLate(ms: Double) {
        lock.withLock { state.worstPhaseLateMs = max(state.worstPhaseLateMs, ms) }
    }

    func recordSkip() { lock.withLock { state.cuesSkipped += 1 } }

    func setPhase(_ name: String, endsAt: ContinuousClock.Instant?) {
        lock.withLock {
            state.phase = name
            state.phaseChanges += 1
            endOfPhase = endsAt
            state.paused = false
        }
    }

    func setPaused(remaining: Duration) {
        lock.withLock {
            state.paused = true
            state.remaining = remaining
            endOfPhase = nil
        }
    }

    func setFinished() { lock.withLock { state.finished = true } }

    func snapshot() -> Snapshot {
        lock.withLock {
            var copy = state
            if let endOfPhase { copy.remaining = max(.zero, clock.now.duration(to: endOfPhase)) }
            return copy
        }
    }

    func close() {
        lock.withLock {
            closed = true
            try? handle?.close()
        }
    }
}
