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
    platforms: [.iOS(.v27), .macOS(.v27), .watchOS(.v26)],
    products: [.library(name: "TemperCore", targets: ["TemperCore"])],
    targets: [
        .target(name: "TemperCore", swiftSettings: settings),
        .testTarget(name: "TemperCoreTests", dependencies: ["TemperCore"], swiftSettings: settings),
    ]
)
