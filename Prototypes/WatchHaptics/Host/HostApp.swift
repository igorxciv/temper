// PROTOTYPE, throwaway. Exists only so Xcode can reach the Watch through the iPhone if running the Watch scheme
// directly fails.

import SwiftUI

@main
struct HostApp: App {
    var body: some Scene {
        WindowGroup {
            VStack(spacing: 12) {
                Image(systemName: "applewatch.radiowaves.left.and.right")
                    .font(.system(size: 48))
                Text("Temper haptics prototype")
                    .font(.headline)
                Text("The prototype runs on the Watch. Open \"Haptics Proto\" there.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }
}
