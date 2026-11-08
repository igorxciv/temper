// PROBE, throwaway. A timestamped log, kept on screen and appended to a file in the app's Documents folder.

import Foundation
import Observation
import os

@Observable
final class ProbeLog {
    private(set) var lines: [String] = []
    let fileURL: URL
    private let side: String
    private let logger: Logger

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    init(side: String) {
        self.side = side
        logger = Logger(subsystem: "probe.watchlink", category: side)
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = documents.appending(path: "link-probe.log")
    }

    static func time(_ date: Date) -> String {
        formatter.string(from: date)
    }

    /// Adds a line. `from` names the side the line came from when it isn't this one.
    func add(_ text: String, at date: Date = .now, from: String? = nil) {
        let line = "\(Self.time(date)) [\(from ?? side)] \(text)"
        logger.log("\(line, privacy: .public)")
        lines.append(line)
        if lines.count > 400 { lines.removeFirst(lines.count - 400) }
        append(line + "\n")
    }

    func clear() {
        lines.removeAll()
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func append(_ text: String) {
        let data = Data(text.utf8)
        if let handle = try? FileHandle(forWritingTo: fileURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: fileURL)
        }
    }
}
