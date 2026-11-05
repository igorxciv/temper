// PROTOTYPE, throwaway. Exists only so Xcode can reach a watchOS 26 Watch through the iPhone.

import SwiftUI

@main
struct HostApp: App {
    var body: some Scene {
        WindowGroup {
            VStack(spacing: 12) {
                Image(systemName: "applewatch")
                    .font(.system(size: 48))
                Text("Temper Watch prototype")
                    .font(.headline)
                Text("The prototype runs on the Watch. Open \"Temper Proto\" there.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }
}
