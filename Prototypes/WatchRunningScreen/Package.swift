// swift-tools-version: 6.2
// PROTOTYPE, throwaway. `swift run Snapshots` renders every variant and scenario to PNG contact sheets on macOS.

import PackageDescription

let package = Package(
    name: "WatchRunningPrototype",
    platforms: [.macOS(.v15), .watchOS(.v11)],
    targets: [
        .target(name: "Screens", path: "Screens"),
        .executableTarget(name: "Snapshots", dependencies: ["Screens"], path: "Snapshots"),
    ]
)
