// swift-tools-version: 6.4
import PackageDescription

let settings: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    .defaultIsolation(MainActor.self),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("MemberImportVisibility"),
]

let package = Package(
    name: "TemperCore",
    // The Watch app compiles this package, and stays on watchOS 26 because watchOS 27 drops the Series 8.
    platforms: [.iOS(.v27), .macOS(.v27), .watchOS(.v26)],
    products: [.library(name: "TemperCore", targets: ["TemperCore"])],
    targets: [
        .target(name: "TemperCore", swiftSettings: settings),
        .testTarget(name: "TemperCoreTests", dependencies: ["TemperCore"], swiftSettings: settings),
    ]
)
