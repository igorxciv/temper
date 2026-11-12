#if DEBUG
    import SwiftUI

    /// Shares a saved timing log, since the app has no file sharing keys in its Info.plist.
    struct TimingLogsSection: View {
        let ink: BoardInk

        @State private var logs: [URL] = []

        var body: some View {
            Section {
                ForEach(logs, id: \.self) { log in
                    ShareLink(item: log) {
                        Text(log.lastPathComponent).font(.caption)
                    }
                    .listRowBackground(ink.row)
                }
                if logs.isEmpty {
                    Text("No logs yet.")
                        .foregroundStyle(ink.secondary)
                        .listRowBackground(ink.row)
                }
            } header: {
                Text("Logs").foregroundStyle(ink.marker)
            }
            .onAppear { logs = TimingLog.savedLogs() }
        }
    }
#endif
