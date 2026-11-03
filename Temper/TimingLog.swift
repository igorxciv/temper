#if DEBUG
    import Foundation

    /// A JSONL record of one Workout's timing, read by `Tools/analyze_timing_log.py`. It stays in the app's own
    /// storage, and records audio port types but never port names, which can contain a person's name.
    ///
    /// Writers include the audio tap and notification callbacks, on threads of their own, so a lock guards it.
    nonisolated final class TimingLog: @unchecked Sendable {
        private let lock = NSLock()
        private let handle: FileHandle?
        private let clock = ContinuousClock()
        private let start: ContinuousClock.Instant
        private var calibrationWall = 0.0
        private var calibrationHost = 0.0
        private var cueTargetWall: Double?

        init() {
            let name = Date.now.formatted(
                .iso8601.year().month().day().time(includingFractionalSeconds: false).timeSeparator(.omitted)
            )
            let url = Self.folder.appending(path: "run-\(name).jsonl")
            try? FileManager.default.createDirectory(at: Self.folder, withIntermediateDirectories: true)
            FileManager.default.createFile(atPath: url.path, contents: nil)
            handle = try? FileHandle(forWritingTo: url)
            start = clock.now
        }

        deinit {
            try? handle?.close()
        }

        /// The saved logs, newest first.
        static func savedLogs() -> [URL] {
            let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            return (files ?? [])
                .filter { $0.pathExtension == "jsonl" }
                .sorted { $0.lastPathComponent > $1.lastPathComponent }
        }

        private static var folder: URL {
            URL.applicationSupportDirectory.appending(path: "TimingLogs")
        }

        /// Seconds since this log began, on the same clock the Workout engine uses.
        var wall: Double {
            start.duration(to: clock.now) / .seconds(1)
        }

        func write(_ kind: String, _ fields: [String: any Sendable] = [:]) {
            var object: [String: Any] = ["e": kind, "wall": wall]
            object.merge(fields) { _, new in new }
            guard JSONSerialization.isValidJSONObject(object),
                let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
            else { return }
            lock.withLock {
                handle?.write(data + Data("\n".utf8))
            }
        }

        /// Pairs the host clock with `wall`. The host clock stops while the device sleeps, so this is done at each
        /// Cue's handover, to keep the pairing true for that Cue.
        func calibrate(hostSeconds: Double) {
            let now = wall
            lock.withLock {
                calibrationWall = now
                calibrationHost = hostSeconds
            }
        }

        func wall(forHostSeconds host: Double) -> Double {
            lock.withLock { calibrationWall + (host - calibrationHost) }
        }

        func setCueTarget(_ wall: Double?) {
            lock.withLock { cueTargetWall = wall }
        }

        func recordOnset(wall onset: Double) {
            var fields: [String: any Sendable] = ["onset_wall": onset]
            if let target = lock.withLock({ cueTargetWall }) {
                fields["error_ms"] = (onset - target) * 1000
            }
            write("onset", fields)
        }
    }
#endif
