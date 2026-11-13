#if DEBUG
    import SwiftUI

    /// Shares a saved timing log, since the app has no file sharing keys in its Info.plist.
    struct TimingLogsSection: View {
        let colors: InkColors

        @State private var logs: [URL] = []

        var body: some View {
            Section {
                ForEach(logs, id: \.self) { log in
                    ShareLink(item: log) {
                        Text(log.lastPathComponent).font(.caption)
                    }
                    .listRowBackground(colors.raised)
                }
                if logs.isEmpty {
                    Text("No logs yet.").listRowBackground(colors.raised)
                }
            } header: {
                Text("Logs").foregroundStyle(colors.secondary)
            }
            .onAppear { logs = TimingLog.savedLogs() }
        }
    }
#endif
